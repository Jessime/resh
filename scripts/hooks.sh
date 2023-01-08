#!/hint/sh

__resh_reload_shellrc() {
    source ~/.resh/shellrc
    printf '\n'
    printf '+--------------------------------------------------------------+\n'
    printf '| New version of RESH shell files was loaded in this terminal. |\n'
    printf '| This is an informative message - no action is necessary.     |\n'
    printf '| Please restart this terminal if you encounter any issues.    |\n'
    printf '+--------------------------------------------------------------+\n'
    printf '\n'
}

# BACKWARDS COMPATIBILITY NOTES:
#
# Stable names and options:
# * `resh-collect -version` / `resh-postcollect -version` is used to detect version mismatch.
#   => The go-like/short `-version` option needs to exist for new resh-(post)collect commands in all future version.
#   => Prefer using go-like/short `-version` option so that we don't have more options to support indefinitely.
# * `__resh_preexec <CMDLINE>` with `__RESH_NO_RELOAD=1` is called on version mismatch.
#   => The `__resh_preexec` function needs to exist in all future versions.
#   => Make sure that `__RESH_NO_RELOAD` behavior is not broken in any future version.
#   => Prefer only testing `__RESH_NO_RELOAD` for emptyness instead of specific value
# Other:
# - Return status code of `resh-collect` and `resh-postcollect` commands from `__resh_preexec` and `__resh_precmd` respectively.
#   - Even nested calls of `__resh_preexec` should propagate the status.


# (pre)collect
# Backwards compatibilty: Please see notes above before making any changes here.
__resh_preexec() {
    # $1 is command line
    # $2 can be --no-reload opt
    # Backwards compatibity: Do not change -version opt.
    #                        It is called by new shell files to detect version mismatch.
    if [ "$(resh-collect -version)" != "$__RESH_VERSION" ] && [ -z "${__RESH_NO_RELOAD-}" ]; then
        # Reload shell files and restart __resh_preexec - i.e. the full command will be recorded only with a slight delay.
        # This should happens in every already open terminal after resh update.

        # If `$2` is non-empty we play it safe, don't reload, and leave it up to resh-collect to error because of `--required-version` option.
        # This behavior gives user and error instead of handling things silently and risking infinite recursion.

        __resh_reload_shellrc
        # Rerun self but prevent another reload. Extra protection against infinite recursion.
        __RESH_NO_RELOAD=1 __resh_preexec "$@"
        return $?
    fi
    __RESH_COLLECT=1
    __RESH_RECORD_ID=$(resh-generate-uuid)
    # TODO: do this in resh-collect
    # shellcheck disable=2155
    local git_remote="$(git remote get-url origin 2>/dev/null)"
    # TODO: do this in resh-collect
    __RESH_RT_BEFORE=$(resh-get-epochtime)
    resh-collect -requireVersion "$__RESH_VERSION" \
        --git-remote "$git_remote" \
        --home "$HOME" \
        --pwd "$PWD" \
        --record-id "$__RESH_RECORD_ID" \
        --session-id "$__RESH_SESSION_ID" \
        --session-pid "$$" \
        --shell "$__RESH_SHELL" \
        --shlvl "$SHLVL" \
        --time "$__RESH_RT_BEFORE" \
        --cmd-line "$1"
    return $?
}

# postcollect
# Backwards compatibilty: Please see notes above before making any changes here.
__resh_precmd() {
    # Get status first before it gets overriden by another command.
    local exit_code=$?
    # Don't do anything if __resh_preexec was not called.
    # There are situations (in bash) where no command was submitted but __resh_precmd gets called anyway.
    [ -n "${__RESH_COLLECT-}" ] || return
    if [ "$(resh-postcollect -version)" != "$__RESH_VERSION" ]; then
        # Reload shell files and return - i.e. skip recording part2 for this command.
        # We don't call __resh_precmd because the new __resh_preexec might not be backwards compatible with variables set by old __resh_preexec.
        # This should happen only in the one terminal where resh update was executed.
        # And the resh-daemon was likely restarted so we likely don't even have the matching part1 of the comand in the resh-daemon memory.
        __resh_reload_shellrc
        return
    fi
    unset __RESH_COLLECT

    # do this in resh-postcollect
    # shellcheck disable=2155
    local rt_after=$(resh-get-epochtime)
    resh-postcollect -requireVersion "$__RESH_VERSION" \
        --exit-code "$exit_code" \
        --record-id "$__RESH_RECORD_ID" \
        --session-id "$__RESH_SESSION_ID" \
        --shlvl "$SHLVL" \
        --time-after "$rt_after" \
        --time-before "$__RESH_RT_BEFORE"
    return $?
}

# Backwards compatibilty: No restrictions. This is only used at the start of the session.
__resh_session_init() {
    resh-session-init -requireVersion "$__RESH_VERSION" \
        --session-id "$__RESH_SESSION_ID" \
        --session-pid "$$"
    return $?
}