# ============================================================================
#  conf.d/colors.fish — Catppuccin Frappe colors for syntax highlighting.
#  Loaded on every interactive session before the prompt, so colors are
#  guaranteed even on fish 4.3+ where fish_color_* vars are not universal.
#
#  Result:
#    - GREEN: command exists / is installed
#    - RED  : command does not exist / is not installed
#    - params blue, options lilac, strings yellow, comments grey, ops pink
# ============================================================================

set -g fish_color_command        a6d189
set -g fish_color_error          e78284
set -g fish_color_autosuggestion 626880
set -g fish_color_valid_path     --underline
set -g fish_color_param          8caaee
set -g fish_color_quote          e5c890
set -g fish_color_option         ca9ee6
set -g fish_color_comment        626880
set -g fish_color_operator       f4b8e4
set -g fish_color_redirection    c6d0f5
set -g fish_color_end            ef9f76
set -g fish_color_keyword        ca9ee6
set -g fish_color_escape         f4b8e4
set -g fish_color_cwd            8caaee
set -g fish_color_cwd_root       e78284
set -g fish_color_user            a6d189
set -g fish_color_host            ca9ee6
set -g fish_color_history_current --bold
set -g fish_color_match          --background=brblue
set -g fish_color_selection      --background=414559
set -g fish_color_search_match   --background=414559
set -g fish_color_status         e78284
set -g fish_color_cancel         e78284 --reverse

# Pager (completion menu shown on TAB)
set -g fish_pager_color_progress            626880
set -g fish_pager_color_completion          c6d0f5
set -g fish_pager_color_description         626880
set -g fish_pager_color_prefix             a6d189 --bold
set -g fish_pager_color_selected_background --background=414559
set -g fish_pager_color_selected_prefix    a6d189 --bold