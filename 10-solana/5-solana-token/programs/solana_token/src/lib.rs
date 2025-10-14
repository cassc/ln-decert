use anchor_lang::prelude::*;
use anchor_spl::token::{self, Mint, MintTo, Token, TokenAccount};

declare_id!("C42Gh6Ruv5fayWFH8SVNCFq3bKxbNQV3VH1PKactiQRv");

const TOKEN_STATE_SEED: &[u8] = b"token-state";

#[program]
pub mod solana_token {
    use super::*;

    pub fn initialize_mint(ctx: Context<InitializeMint>, decimals: u8) -> Result<()> {
        let state = &mut ctx.accounts.state;
        state.mint = ctx.accounts.mint.key();
        state.authority = ctx.accounts.authority.key();
        state.bump = ctx.bumps.state;
        state.decimals = decimals;

        Ok(())
    }

    pub fn mint_tokens(ctx: Context<MintTokens>, amount: u64) -> Result<()> {
        let state = &ctx.accounts.state;

        require_keys_eq!(ctx.accounts.authority.key(), state.authority, TokenError::Unauthorized);
        require_keys_eq!(ctx.accounts.recipient.mint, state.mint, TokenError::InvalidRecipient);

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
#[instruction(decimals: u8)]
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
}
