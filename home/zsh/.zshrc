# Glass Shell zsh (the login shell; install.sh runs chsh). Kept small: history, completion, a prompt.

# Powerlevel10k instant prompt: draws the last prompt at once while the rest loads. Stays at the top;
# anything that needs keyboard input (password prompts, y/n) goes above it.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Claude Code and other user tools live here.
export PATH="$HOME/.local/bin:$PATH"
export EDITOR=nvim

HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt share_history hist_ignore_dups hist_ignore_space autocd

autoload -Uz compinit && compinit
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'
bindkey -e

alias ls='ls --color=auto'
alias grep='grep --color=auto'

# Prompt: Powerlevel10k (AUR zsh-theme-powerlevel10k), set up in ~/.p10k.zsh. Until it's installed,
# a plain one: user@host dir, git branch, ❯ in red after a failed command.
p10k_theme=/usr/share/zsh-theme-powerlevel10k/powerlevel10k.zsh-theme
if [[ -r $p10k_theme ]]; then
  source $p10k_theme
  source ~/.p10k.zsh
else
  autoload -Uz vcs_info
  precmd() { vcs_info }
  zstyle ':vcs_info:git:*' formats ' %F{magenta}%b%f'
  setopt prompt_subst
  PROMPT='%F{blue}%n@%m%f %~${vcs_info_msg_0_} %(?.%F{green}.%F{red})❯%f '
fi
unset p10k_theme
