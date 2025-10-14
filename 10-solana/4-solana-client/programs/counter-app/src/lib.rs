#![allow(unexpected_cfgs)]
#![allow(deprecated)]

use anchor_lang::prelude::*;

declare_id!("AxEx7K72AZiwkxgwxw3KkEtjAc6ezdPxcYK3zFJd3Qgu"); // replace after first deploy

#[program]
pub mod counter_app {
    use super::*;

    pub fn initialize(ctx: Context<Initialize>) -> Result<()> {
        let counter = &mut ctx.accounts.counter;
        counter.bump = ctx.bumps.counter;
        counter.authority = ctx.accounts.user.key();
        counter.count = 0;
        Ok(())
    }

    pub fn increment(ctx: Context<Increment>) -> Result<()> {
        let counter = &mut ctx.accounts.counter;
        require_keys_eq!(counter.authority, ctx.accounts.user.key(), CustomError::Unauthorized);
        counter.count = counter.count.checked_add(1).ok_or(ErrorCode::NumericalOverflow)?;
        Ok(())
    }
}

#[derive(Accounts)]
pub struct Initialize<'info> {
    #[account(
        init,
        payer = user,
        seeds = [b"counter", user.key().as_ref()],
        bump,
        space = 8 + 1 + 32 + 8 // discriminator + bump + authority + count
    )]
    pub counter: Account<'info, Counter>,
    #[account(mut)]
    pub user: Signer<'info>,
    pub system_program: Program<'info, System>,
}

#[derive(Accounts)]
pub struct Increment<'info> {
    #[account(
        mut,
        seeds = [b"counter", user.key().as_ref()],
        bump = counter.bump
    )]
    pub counter: Account<'info, Counter>,
    pub user: Signer<'info>,
}

#[account]
pub struct Counter {
    pub bump: u8,
    pub authority: Pubkey,
    pub count: u64,
}

#[error_code]
pub enum CustomError {
    #[msg("Only the authority can increment the counter.")]
    Unauthorized,
}

#[error_code]
pub enum ErrorCode {
    #[msg("Numerical overflow")]
    NumericalOverflow,
}
