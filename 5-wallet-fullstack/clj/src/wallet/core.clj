(ns wallet.core
  (:gen-class)
  (:require [clojure.tools.cli :refer [parse-opts]]
            [cheshire.core :as json])
  (:import (org.web3j.crypto Keys Credentials RawTransaction TransactionEncoder WalletUtils)
           (org.web3j.protocol Web3j)
           (org.web3j.protocol.http HttpService)
           (org.web3j.protocol.core DefaultBlockParameterName)
           (org.web3j.protocol.core.methods.request Transaction)
           (org.web3j.protocol.core.methods.response EthBlock$Block)
           (org.web3j.abi FunctionEncoder FunctionReturnDecoder TypeReference)
           (org.web3j.abi.datatypes Function Type)
           (org.web3j.abi.datatypes.generated Uint256)
           (org.web3j.abi.datatypes Address)
           (org.web3j.utils Numeric Convert Convert$Unit)
           (java.math BigInteger BigDecimal)
           (java.nio.file Files StandardCopyOption)
           (java.time Instant)
           (java.util Arrays Collections)))

(def default-key-file "wallet-account.json")

(defn now-iso []
  (.toString (Instant/now)))

(defn write-json [path data]
  (spit path (json/generate-string data {:pretty true})))

(defn read-json [path]
  (json/parse-string (slurp path) true))

(defn ensure-0x [hex]
  (if (.startsWith ^String hex "0x") hex (str "0x" hex)))

(defn format-private-key [kp]
  (ensure-0x (Numeric/toHexStringNoPrefix (.getPrivateKey kp))))

(defn format-address [kp]
  (let [addr (Keys/getAddress kp)]
    (ensure-0x (Keys/toChecksumAddress addr))))

(defn keygen [{:keys [out password]}]
  (let [kp (Keys/createEcKeyPair)
        priv (format-private-key kp)
        addr (format-address kp)
        record {:address addr
                :private-key priv
                :created-at (now-iso)}
        target (or out default-key-file)]
    (if password
      (let [out-file (java.io.File. target)
            parent (.getParentFile out-file)
            _ (when parent (.mkdirs parent))
            dir (or parent (java.io.File. "."))
            generated (WalletUtils/generateWalletFile password kp dir false)
            source (.resolve (.toPath dir) generated)
            dest (.toPath out-file)]
        (when (and dest (not (.equals source dest)))
          (Files/move source dest (into-array java.nio.file.CopyOption [StandardCopyOption/REPLACE_EXISTING])))
        (println "Saved encrypted key to" (str (.toAbsolutePath dest)))
        (println "Address:" addr)
        (println "Private key:" priv))
      (do
        (write-json target record)
        (println "Saved new key to" target)
        (println "Address:" addr)
        (println "Private key:" priv)))))

(defn load-credentials [{:keys [key-file private-key password]}]
  (cond
    private-key (Credentials/create (Numeric/cleanHexPrefix private-key))
    key-file (let [content (slurp key-file)
                   parsed (try
                            (json/parse-string content true)
                            (catch Exception _ ::parse-error))]
               (cond
                 (and (map? parsed) (:private-key parsed))
                 (Credentials/create (Numeric/cleanHexPrefix (:private-key parsed)))
                 password (WalletUtils/loadCredentials password key-file)
                 :else (throw (ex-info "Encrypted wallet needs --password" {:file key-file}))))
    :else (throw (ex-info "Need --key-file or --private-key" {}))))

(defn web3 [rpc]
  (Web3j/build (HttpService. rpc)))

(defn wei->eth [wei]
  (.toPlainString (Convert/fromWei (BigDecimal. wei) Convert$Unit/ETHER)))

(defn gwei->wei [gwei]
  (Convert/toWei (BigDecimal. (str gwei)) Convert$Unit/GWEI))

(defn parse-amount [amount decimals]
  (let [bd (BigDecimal. amount)
        scale (.movePointRight bd decimals)]
    (.toBigIntegerExact scale)))

(defn fetch-eth-balance [w3 address]
  (let [resp (.send (.ethGetBalance w3 address DefaultBlockParameterName/LATEST))]
    (if (.hasError resp)
      (throw (ex-info "RPC error" {:message (.getMessage (.getError resp))}))
      (.getBalance resp))))

(defn call-contract [w3 from to data]
  (let [tx (Transaction/createEthCallTransaction from to data)
        resp (.send (.ethCall w3 tx DefaultBlockParameterName/LATEST))]
    (if (.hasError resp)
      (throw (ex-info "RPC error" {:message (.getMessage (.getError resp))}))
      (.getResult resp))))

(defn decode-uint256 [hex]
  (if (or (nil? hex) (= "0x" hex))
    BigInteger/ZERO
    (let [types (FunctionReturnDecoder/decode hex (Collections/singletonList (TypeReference/create Uint256)))]
      (.getValue ^Uint256 (first types)))))

(defn fetch-erc20-decimals [w3 token]
  (try
    (let [fn (Function. "decimals" (Collections/emptyList) (Collections/singletonList (TypeReference/create Uint256)))
          data (FunctionEncoder/encode fn)
          raw (call-contract w3 nil token data)
          value (decode-uint256 raw)]
      (.intValue value))
    (catch Exception _ 18)))

(defn fetch-erc20-balance [w3 token holder]
  (let [inputs (Arrays/asList (into-array Type [(Address. holder)]))
        fn (Function. "balanceOf" inputs (Collections/singletonList (TypeReference/create Uint256)))
        data (FunctionEncoder/encode fn)
        raw (call-contract w3 holder token data)]
    (decode-uint256 raw)))

(defn show-balance [{:keys [rpc address token decimals]}]
  (when-not (and rpc address)
    (throw (ex-info "Need --rpc and --address" {})))
  (with-open [w3 (web3 rpc)]
    (let [eth-wei (fetch-eth-balance w3 address)]
      (println "ETH balance(wei):" eth-wei)
      (println "ETH balance:" (wei->eth eth-wei))
      (when token
        (let [token-dec (or decimals (fetch-erc20-decimals w3 token))
              bal (fetch-erc20-balance w3 token address)
              human (.toPlainString (.movePointLeft (BigDecimal. bal) token-dec))]
          (println "Token balance:" human)
          (println "Token raw:" bal)
          (println "Token decimals:" token-dec))))))

(defn latest-block [w3]
  (let [resp (.send (.ethGetBlockByNumber w3 DefaultBlockParameterName/LATEST false))]
    (if (.hasError resp)
      (throw (ex-info "RPC error" {:message (.getMessage (.getError resp))}))
      (.getBlock resp))))

(defn base-fee [^EthBlock$Block block]
  (let [value (.getBaseFeePerGas block)]
    (if value (Numeric/decodeQuantity value) BigInteger/ZERO)))

(defn max-priority-fee [w3]
  (try
    (let [resp (.send (.ethMaxPriorityFeePerGas w3))]
      (if (.hasError resp)
        (BigInteger/valueOf 2000000000)
        (.getMaxPriorityFeePerGas resp)))
    (catch Exception _ (BigInteger/valueOf 2000000000))))

(defn nonce [w3 address]
  (let [resp (.send (.ethGetTransactionCount w3 address DefaultBlockParameterName/PENDING))]
    (if (.hasError resp)
      (throw (ex-info "RPC error" {:message (.getMessage (.getError resp))}))
      (.getTransactionCount resp))))

(defn parse-long* [v default]
  (if v
    (Long/parseLong (str v))
    default))

(defn parse-int* [v default]
  (if v
    (Integer/parseInt (str v))
    default))

(defn encode-transfer [to amount]
  (let [inputs (Arrays/asList (into-array Type [(Address. to) (Uint256. amount)]))
        fn (Function. "transfer" inputs (Collections/emptyList))]
    (FunctionEncoder/encode fn)))

(defn send-raw [w3 hex]
  (let [resp (.send (.ethSendRawTransaction w3 hex))]
    (if (.hasError resp)
      (throw (ex-info "RPC error" {:message (.getMessage (.getError resp))}))
      (.getTransactionHash resp))))

(defn build-transfer [{:keys [rpc key-file private-key password token to amount decimals gas-limit max-priority max-fee chain-id send?]}]
  (when-not (and rpc token to amount)
    (throw (ex-info "Need --rpc --token --to --amount" {})))
  (with-open [w3 (web3 rpc)]
    (let [creds (load-credentials {:key-file key-file :private-key private-key :password password})
          from-raw (.getAddress creds)
          from (ensure-0x (Keys/toChecksumAddress (Numeric/cleanHexPrefix from-raw)))
          token-dec (parse-int* (or decimals (fetch-erc20-decimals w3 token)) 18)
          amount-raw (parse-amount amount token-dec)
          data (encode-transfer to amount-raw)
          nonce-v (nonce w3 from)
          latest (latest-block w3)
          base (base-fee latest)
          priority (if max-priority
                     (.toBigIntegerExact (gwei->wei max-priority))
                     (max-priority-fee w3))
          fee (if max-fee
                (.toBigIntegerExact (gwei->wei max-fee))
                (.add (.multiply base (BigInteger/valueOf 2)) priority))
          gas (BigInteger/valueOf (parse-long* gas-limit 100000))
          chain-long (parse-long* (or chain-id 11155111) 11155111)
          raw (RawTransaction/createTransaction chain-long nonce-v gas token BigInteger/ZERO data priority fee)
          signed (TransactionEncoder/signMessage raw chain-long creds)
          hex (Numeric/toHexString signed)]
      (println "From:" from)
      (println "Nonce:" nonce-v)
      (println "Gas limit:" gas)
      (println "Max priority fee (wei):" priority)
      (println "Max fee (wei):" fee)
      (println "Data:" data)
      (println "Signed tx:" hex)
      (when send?
        (let [tx-hash (send-raw w3 hex)]
          (println "Sent tx hash:" tx-hash))))))

(def cli-options
  {:keygen [["-o" "--out FILE" "Key file path" :default default-key-file]
            ["-P" "--password PASS" "Encrypt wallet with password"]]
   :balance [["-r" "--rpc URL" "RPC HTTP URL"]
             ["-a" "--address ADDRESS" "Account address"]
             ["-t" "--token ADDRESS" "ERC20 contract" :default nil]
             ["-d" "--decimals N" "Token decimals" :parse-fn #(Integer/parseInt %)]]
   :transfer [["-r" "--rpc URL" "RPC HTTP URL"]
              ["-k" "--key-file FILE" "Key JSON file" :default default-key-file]
              ["-p" "--private-key HEX" "Private key hex"]
              ["-t" "--token ADDRESS" "ERC20 contract"]
              ["-o" "--to ADDRESS" "Recipient address"]
              ["-a" "--amount VALUE" "Token amount"]
              ["-d" "--decimals N" "Token decimals" :parse-fn #(Integer/parseInt %)]
              ["-g" "--gas-limit N" "Gas limit" :default 100000]
              ["--max-priority GWEI" "Max priority fee in gwei"]
              ["--max-fee GWEI" "Max fee in gwei"]
              ["--password PASS" "Wallet password"]
              ["-c" "--chain-id N" "Chain id" :default 11155111]
              ["-s" "--send" "Send transaction" :default false :flag true]]})

(defn usage []
  (str "wallet <command> [options]\n\n"
       "Commands:\n"
       "  keygen     Generate and store a private key\n"
       "  balance    Query ETH or ERC20 balance\n"
       "  transfer   Build, sign, and optionally send ERC20 transfer\n"))

(defn exit [status msg]
  (binding [*out* (if (zero? status) *out* *err*)]
    (println msg))
  (System/exit status))

(defn handle-keygen [args]
  (let [{:keys [options errors]} (parse-opts args (:keygen cli-options))]
    (when errors (exit 1 (first errors)))
    (keygen options)))

(defn handle-balance [args]
  (let [{:keys [options errors]} (parse-opts args (:balance cli-options))]
    (when errors (exit 1 (first errors)))
    (show-balance options)))

(defn handle-transfer [args]
  (let [{:keys [options errors]} (parse-opts args (:transfer cli-options))]
    (when errors (exit 1 (first errors)))
    (try
      (build-transfer (assoc options :send? (:send options)))
      (catch Exception e
        (exit 1 (str "Transfer failed: " (.getMessage e)))))))

(defn main [& args]
  (let [[command & rest] args]
    (try
      (case command
        "keygen" (handle-keygen rest)
        "balance" (handle-balance rest)
        "transfer" (handle-transfer rest)
        (exit 1 (usage)))
      (catch Exception e
        (exit 1 (str (.getMessage e)))))))

(defn -main [& args]
  (apply main args))

(comment

  ;; generate wallet with password
  (handle-keygen ["-o" "wallet-account.json" "-P" "testpassword"])

  ;; load wallet credentials
  (let [creds (wallet.core/load-credentials {:key-file "wallet-account.json"
                                             :password "testpassword"})
        key   (wallet.core/format-private-key (.getEcKeyPair creds))]
    (println key))


  )
