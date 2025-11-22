use std log

# ------------------------------------
# SDKMAN Nushell Compatibility Script
# ------------------------------------
#
# Makes command and binaries from SDKMAN! available in nushell.
# Delegates to bash for the `sdk` command.
#
# Based on: https://github.com/reitzig/sdkman-for-fish/blob/main/conf.d/sdk.fish
# ------------------------------------
export-env {
    # $env.NU_LOG_LEVEL = "DEBUG" # Enable for debug information
}

def --env validate_installation [] {
    log debug "Validating SDKMAN installation"

    # Check if custom install location is set
    if ($env.__SDKMAN_CUSTOM_DIR? | is-not-empty) {
        $env.SDKMAN_DIR = $env.__SDKMAN_CUSTOM_DIR
    }

    # Guard: SDKMAN! needs to be installed
    if ($env.SDKMAN_DIR? | is-empty) or not ($env.SDKMAN_DIR? | path exists) {
        error make {msg: $"WARNING: SDKMAN! installation path set to ($env.SDKMAN_DIR), but no installation found there."}
    }

    # Default SDKMAN location if not set
    if ($env.SDKMAN_DIR | is-empty) {
        $env.SDKMAN_DIR = ($env.HOME | path join '.sdkman')
    }

    # Guard: SDKMAN! init script must exist
    let sdkman_init = ($env.SDKMAN_DIR | path join 'bin/sdkman-init.sh')
    if not ( $sdkman_init | path exists ) {
        error make {msg: $"WARNING: SDKMAN! init script must exist"}
    }

    log debug "SDKMAN installation OK"
}

# Load SDKMAN environment variables
def --env load_sdkman_env [cmd: string] {
    validate_installation

    log debug $"Calling bash with command: '($cmd)'"

    # Temporary file to capture bash output
    let pipe = (mktemp)

    # Use bash to initialize SDKMAN and capture environment variables
    bash -c $"($cmd);
             echo -e \"\$?\" > ($pipe).exit;
             env | rg -e '^SDKMAN_\|^PATH' >> ($pipe);
             env | rg -i \"^\(`echo \${SDKMAN_CANDIDATES_CSV} | sed 's/,/|/g'`\)_HOME\" >> ($pipe);
             echo \"SDKMAN_OFFLINE_MODE=\${SDKMAN_OFFLINE_MODE}\" >> ($pipe);
             echo \"SDKMAN_ENV=\${SDKMAN_ENV}\" >> ($pipe)" # it's not an environment variable!

    # # Read exit code and env separately
    let exit_code = (open ($pipe + '.exit') | first)
    log debug $"exit_code : ($exit_code)"
    rm ($pipe + '.exit')

    let env_output = (open $pipe | lines)
    log debug $"env_output : ($env_output)"
    rm $pipe

    if $exit_code != 0 {
        log debug $"SDKMAN initialization exit code: ($exit_code), continuing anyway..."
        # error make { msg: "SDKMAN! failed to initialize (bash returned non-zero)." }
    }

    for line in $env_output {
        let tuple = (echo $line | parse "{key}={value}")
        let key = ($tuple.key | first)
        let value = ($tuple.value | first)

        if $key == "PATH" {
            # Find or assign default OS
            let os = ($nu.os-info.family | default "unix")

            # Determine path separator OS
            let sep = if $os == "windows" { ";" } else { ":" }
            log debug $"OS = ($os), separator = ($sep)"

            let old_paths = ($env.PATH | split row $sep)
            let new_paths = ($value | split row $sep)

            # Merge paths, preserve order and uniqueness
            let combined_paths = ($old_paths ++ $new_paths | uniq)

            $env.PATH = $combined_paths
        } else {
            # Set other environment variables
            load-env { $key: $value }
        }
    }

    log debug "SDKMAN environment loaded OK"
}


# Function to run SDKMAN's init script in Bash and set SDKMAN_OLD_PWD
def sdkman_auto_env [] {
    bash -c $"source ($env.SDKMAN_NOEXPORT_INIT)"
    $env.SDKMAN_OLD_PWD = ($env.PWD)  # Set SDKMAN_OLD_PWD to the current PWD
}


# Check if sdkman_auto_env is enabled in the config file
def verify_sdkman_auto_env [] {
    log debug "Checking if sdkman_auto_env is enabled"
    if ($env.SDKMAN_DIR | path join etc/config
                        | open
                        | lines
                        | find --regex '^sdkman_auto_env=true'
                        | is-not-empty) {

        log debug "Auto env is enabled. Adding hook to check for changes in PWD"
        # Watch for changes in PWD and trigger the function when it changes
        $env.config = ($env.config | upsert hooks {
            env_change: {
                PWD: [
                    {
                        condition: {|before, after| $before != $after }
                        code: {|before, after|
                            sdkman_auto_env
                        }
                    }
                ]
            }
        })
        log debug "Hook added OK"
    }
}

# Changes JAVA_HOME to given JDK version
export def --env jdk [version?:string] {
    log debug $"Requested JDK version: ($version)"
    let selected = (ls ($env.SDKMAN_CANDIDATES_DIR | path join 'java')
                        | get name
                        | parse "{path}/candidates/{candidate}/{major}.{minor}.{patch}-tem"
                        | where major == $version
                        | sort-by minor patch --reverse
                        | each { |c| $'($c.major).($c.minor).($c.patch)-tem'}
                        | first)

    log debug $"Selected JDK: ($selected)"
    sdk use java $selected

    echo $"JAVA_HOME is now: ($env.JAVA_HOME)"
    java -version
}

def is_sdkman_installed [] {
    (($env.SDKMAN_DIR? | path exists)
      and ($env.SDKMAN_DIR | path join "bin/sdkman-init.sh" | path exists))
}

# Wrapper function for SDKMAN! ------------------------------------------------

# Check if SDKMAN is installed and if not, prompt for installation
export def --env sdk [...args] {
    log debug $"Verifying sdkman is installed ..."
    if (not (is_sdkman_installed)) {
        error make {msg: "NO SDKMAN installation found!"}
    }
    log debug $"Verifying sdkman is installed OK"

    log debug $"Verifying auto env ..."
    verify_sdkman_auto_env
    log debug $"verifying auto env OK"

    # Guard: SDKMAN! needs to be installed
    let sdkman_init = ($env.SDKMAN_DIR | path join 'bin/sdkman-init.sh')

    log debug $"sdkman_init = ($sdkman_init)"

    # Run SDKMAN initialization in bash if needed
    if (($env.SDKMAN_CANDIDATES_DIR? | is-empty)
        or (not ($env.SDKMAN_CANDIDATES_DIR | path exists))
        or (ls -lD $env.SDKMAN_CANDIDATES_DIR | get user | first) != (whoami)) {

        load_sdkman_env $"source ($sdkman_init)"
    }

    if ($sdkman_init | path exists) {
        # Run the actual sdk command in Nushell
        let content = ($sdkman_init
                                | open --raw
                                | lines
                                | str replace --all --regex "\\s*export .*" ':' # Remove export lines
                                | str replace --all --regex "\\s*__sdkman_export_candidate_home .*" ':' # Remove function execution
                                | str replace --all --regex "\\s*__sdkman_prepend_candidate_to_path .*" ':' # Remove function execution
                                | str join "\n")

        $env.SDKMAN_NOEXPORT_INIT = $content;
        log debug $"SDKMAN_NOEXPORT_INIT: ($content)"

        load_sdkman_env $"eval ($env.SDKMAN_NOEXPORT_INIT) && sdk ($args | str join ' ')"

    } else {
        # Function to prompt user for confirmation
        def read_confirm [message] {
            loop {
                let confirm = (prompt $message "[y/N] ")

                if $confirm == 'y' or $confirm == 'Y' {
                    return true
                } else if $confirm == 'n' or $confirm == 'N' or $confirm == '' {
                    return false
                }
            }
        }

        # Propose to install SDKMAN if not found
        if (read_confirm "You don't seem to have SDKMAN! installed. Install now?") {
            # Check if curl is installed
            if (which curl | get path | is-empty) {
                error make {msg: "curl required"}
            }

            # Check if bash is installed
            if (which bash | get path | is-empty) {
                error make {msg: "bash required"}
            }

            # Install SDKMAN using curl
            bash -c 'curl -s "https://get.sdkman.io" | bash | sed "/All done!/q"'
            print "Please open a new terminal/shell to load SDKMAN!"
        }
    }

}
