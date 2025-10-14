#![allow(unexpected_cfgs)]
#![allow(deprecated)]

use anchor_lang::prelude::*;
use anchor_lang::solana_program::program::invoke_signed;
use anchor_spl::token::{self, Mint, MintTo, Token, TokenAccount};
use mpl_token_metadata::accounts::Metadata;
use mpl_token_metadata::instructions::{
    CreateMetadataAccountV3, CreateMetadataAccountV3InstructionArgs,
};
use mpl_token_metadata::types::DataV2;
use mpl_token_metadata::ID as TOKEN_METADATA_PROGRAM_ID;

declare_id!("ErdLiDbat2pkpij1ykatMERv2hkFmv6V8RgC77jfFcCD");

const TOKEN_STATE_SEED: &[u8] = b"token-state";

#[program]
pub mod solana_token {
    use super::*;

    pub fn initialize_mint(
        ctx: Context<InitializeMint>,
        decimals: u8,
        name: String,
        symbol: String,
        uri: String,
    ) -> Result<()> {
        let state = &mut ctx.accounts.state;
        state.mint = ctx.accounts.mint.key();
        state.authority = ctx.accounts.authority.key();
        state.bump = ctx.bumps.state;
        state.decimals = decimals;

        // Create metadata account
        let mint_key = ctx.accounts.mint.key();
        let bump_seed = &[ctx.bumps.state];
        let signer_seeds: &[&[u8]] = &[TOKEN_STATE_SEED, mint_key.as_ref(), bump_seed];

        let metadata_account = &ctx.accounts.metadata;
        let mint = &ctx.accounts.mint;
        let mint_authority = &ctx.accounts.state;
        let payer = &ctx.accounts.payer;
        let update_authority = &ctx.accounts.authority;
        let system_program = &ctx.accounts.system_program;
        let rent = &ctx.accounts.rent;
        let token_metadata_program = &ctx.accounts.token_metadata_program;

        require_keys_eq!(
            token_metadata_program.key(),
            TOKEN_METADATA_PROGRAM_ID,
            TokenError::InvalidMetadataProgram
        );

        let (expected_metadata_key, _) = Metadata::find_pda(&mint_key);
        require_keys_eq!(
            metadata_account.key(),
            expected_metadata_key,
            TokenError::InvalidMetadataAccount
        );

        let create_metadata_ix = CreateMetadataAccountV3 {
            metadata: metadata_account.key(),
            mint: mint.key(),
            mint_authority: mint_authority.key(),
            payer: payer.key(),
            update_authority: (update_authority.key(), true),
            system_program: system_program.key(),
            rent: None,
        };

        let metadata_infos = vec![
            token_metadata_program.to_account_info(),
            metadata_account.to_account_info(),
            mint.to_account_info(),
            mint_authority.to_account_info(),
            payer.to_account_info(),
            update_authority.to_account_info(),
            system_program.to_account_info(),
            rent.to_account_info(),
        ];

        let create_metadata_args = CreateMetadataAccountV3InstructionArgs {
            data: DataV2 {
                name,
                symbol,
                uri,
                seller_fee_basis_points: 0,
                creators: None,
                collection: None,
                uses: None,
            },
            is_mutable: true,
            collection_details: None,
        };

        invoke_signed(
            &create_metadata_ix.instruction(create_metadata_args),
            &metadata_infos,
            &[signer_seeds],
        )?;

        Ok(())
    }

    pub fn mint_tokens(ctx: Context<MintTokens>, amount: u64) -> Result<()> {
        let state = &ctx.accounts.state;

        require_keys_eq!(
            ctx.accounts.authority.key(),
            state.authority,
            TokenError::Unauthorized
        );
        require_keys_eq!(
            ctx.accounts.recipient.mint,
            state.mint,
            TokenError::InvalidRecipient
        );

        let mint_key = ctx.accounts.mint.key();
        let bump_seed = &[state.bump];
        let signer_seeds: [&[u8]; 3] = [TOKEN_STATE_SEED, mint_key.as_ref(), bump_seed];
        let cpi_accounts = MintTo {
            mint: ctx.accounts.mint.to_account_info(),
            to: ctx.accounts.recipient.to_account_info(),
            authority: ctx.accounts.state.to_account_info(),
        };
        let signer = &[&signer_seeds[..]];
        let cpi_context = CpiContext::new_with_signer(
            ctx.accounts.token_program.to_account_info(),
            cpi_accounts,
            signer,
        );

        token::mint_to(cpi_context, amount)?;

        Ok(())
    }
}

#[derive(Accounts)]
#[instruction(decimals: u8, name: String, symbol: String, uri: String)]
pub struct InitializeMint<'info> {
    #[account(mut)]
    pub payer: Signer<'info>,
    #[account(mut)]
    pub authority: Signer<'info>,
    #[account(
        init,
        seeds = [TOKEN_STATE_SEED, mint.key().as_ref()],
        bump,
        payer = payer,
        space = TokenState::SPACE,
    )]
    pub state: Account<'info, TokenState>,
    #[account(
        init,
        payer = payer,
        mint::decimals = decimals,
        mint::authority = state,
        mint::freeze_authority = state,
    )]
    pub mint: Account<'info, Mint>,
    /// CHECK: This account is initialized by Metaplex Token Metadata program
    #[account(mut)]
    pub metadata: UncheckedAccount<'info>,
    /// CHECK: Metaplex Token Metadata program
    #[account(address = TOKEN_METADATA_PROGRAM_ID)]
    pub token_metadata_program: UncheckedAccount<'info>,
    pub system_program: Program<'info, System>,
    pub token_program: Program<'info, Token>,
    pub rent: Sysvar<'info, Rent>,
}

#[derive(Accounts)]
pub struct MintTokens<'info> {
    #[account(mut)]
    pub authority: Signer<'info>,
    #[account(
        mut,
        seeds = [TOKEN_STATE_SEED, mint.key().as_ref()],
        bump = state.bump,
        has_one = mint,
    )]
    pub state: Account<'info, TokenState>,
    #[account(mut)]
    pub mint: Account<'info, Mint>,
    #[account(mut)]
    pub recipient: Account<'info, TokenAccount>,
    pub token_program: Program<'info, Token>,
}

#[account]
pub struct TokenState {
    pub mint: Pubkey,
    pub authority: Pubkey,
    pub bump: u8,
    pub decimals: u8,
}

impl TokenState {
    pub const SPACE: usize = 8 + 32 + 32 + 1 + 1;
}

#[error_code]
pub enum TokenError {
    #[msg("The provided authority is not permitted to perform this action")]
    Unauthorized,
    #[msg("Recipient account does not match the configured mint")]
    InvalidRecipient,
    #[msg("Metadata account does not match the expected PDA")]
    InvalidMetadataAccount,
    #[msg("Incorrect token metadata program account provided")]
    InvalidMetadataProgram,
}
