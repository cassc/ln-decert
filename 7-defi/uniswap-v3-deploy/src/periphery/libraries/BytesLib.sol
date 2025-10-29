// SPDX-License-Identifier: GPL-2.0-or-later
/*
 * @title Solidity 字节数组实用程序
 * @作者 Gonçalo Sá <goncalo.sa@consensys.net>
 *
 * @dev 用 Solidity 编写的用于以太坊合约的字节紧密封装的数组实用程序库。
 * 该库允许您在内存和存储中连接、切片和类型转换字节数组。
 */
pragma solidity >=0.5.0 <0.8.0;

library BytesLib {
    function slice(
        bytes memory _bytes,
        uint256 _start,
        uint256 _length
    ) internal pure returns (bytes memory) {
        require(_length + 31 >= _length, 'slice_overflow');
        require(_start + _length >= _start, 'slice_overflow');
        require(_bytes.length >= _start + _length, 'slice_outOfBounds');

        bytes memory tempBytes;

        assembly {
            switch iszero(_length)
                case 0 {
                    // 获取一些可用内存的位置并将其存储在 tempBytes 中，如下所示
                    // Solidity 确实适用于内存变量。
                    tempBytes := mload(0x40)

                    // 切片结果的第一个字可能是部分的
                    // 从原始数组中读取的字。为了阅读它，我们计算
                    // 该部分单词的长度并开始复制那么多
                    // 字节到数组中。我们复制的第一个单词将以
                    // 我们不关心的数据，但最后一个“lengthmod”字节会
                    // 落在新数组内容的开头。什么时候
                    // 我们完成了复制，我们用以下内容覆盖完整的第一个单词
                    // 切片的实际长度。
                    let lengthmod := and(_length, 31)

                    // 下一行的乘法是必要的
                    // 因为当切片 32 字节的倍数时 (lengthmod == 0)
                    // 以下复制循环正在复制原点的长度
                    // 然后过早结束，不复制它应该复制的一切。
                    let mc := add(add(tempBytes, lengthmod), mul(0x20, iszero(lengthmod)))
                    let end := add(mc, _length)

                    for {
                        // 下一行中的乘法具有相同的确切目的
                        // 就像上面那个一样。
                        let cc := add(add(add(_bytes, lengthmod), mul(0x20, iszero(lengthmod))), _start)
                    } lt(mc, end) {
                        mc := add(mc, 0x20)
                        cc := add(cc, 0x20)
                    } {
                        mstore(mc, mload(cc))
                    }

                    mstore(tempBytes, _length)

                    // 更新空闲内存指针
                    // 像编译器现在一样将数组填充为 32 字节
                    mstore(0x40, and(add(mc, 31), not(31)))
                }
                // 如果我们想要一个零长度的切片，那么我们只返回一个零长度的数组
                default {
                    tempBytes := mload(0x40)
                    // 将我们即将返回的 32 字节切片清零
                    // 我们需要这样做，因为 Solidity 不会进行垃圾收集
                    mstore(tempBytes, 0)

                    mstore(0x40, add(tempBytes, 0x20))
                }
        }

        return tempBytes;
    }

    function toAddress(bytes memory _bytes, uint256 _start) internal pure returns (address) {
        require(_start + 20 >= _start, 'toAddress_overflow');
        require(_bytes.length >= _start + 20, 'toAddress_outOfBounds');
        address tempAddress;

        assembly {
            tempAddress := div(mload(add(add(_bytes, 0x20), _start)), 0x1000000000000000000000000)
        }

        return tempAddress;
    }

    function toUint24(bytes memory _bytes, uint256 _start) internal pure returns (uint24) {
        require(_start + 3 >= _start, 'toUint24_overflow');
        require(_bytes.length >= _start + 3, 'toUint24_outOfBounds');
        uint24 tempUint;

        assembly {
            tempUint := mload(add(add(_bytes, 0x3), _start))
        }

        return tempUint;
    }
}
