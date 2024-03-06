#!/bin/bash
#
# PURPOSE :
#
#       AI do! (aido) & Sudo AI do! (saido) are bash aliases that use a backing function (also included)to execute bash commands that
#       an LLM model has suggested in respose to user's prompt.
#
#       The snippets below can be added to your .bashrc file to provide a handy in-line way to request help from an LLM
#       model if you happen not to have encyclodedic knowledge of bash commands... or have just forgotten the syntax for a particular
#       command and want a very targetted and actionable reminder with no tl;dr.
#
# SAFETY & SECURITY :
#
#       The LLM-suggested bash command is displayed at the command prompt and the user is able to edit it before choosing to execute
#       it by hitting [Enter], or abandon it by hitting [Ctrl-C] or [Ctrl-D]. 
#
#       Nothing is executed without the user's explicit input and consent.
#
#       That being said, this is intended as a proof-of-concept and no safety or security guarantees are made. The user is responsible
#       for the commands they execute. The function uses 'eval' to execute commands, including ones prefixed by 'sudo', which is generally 
#       considered unsafe.
#
# USAGE :
#
#       aido <prompt>
#       saido <prompt>
#
#           - 'aido' calls the function aido_func() with the '-u' user mode switch
#           - 'saido' calls the function aido_func() with the '-a' user mode switch
#           - NOTE A PARAMETER HAS BEEN ADDED FOR VERBOSITY & DEBUGING - see below
#           - <prompt> is the prompt to the LLM model requesting a bash command; additional instructions are prepended to it by the function
#
#       Explanation:
#       - The 'aido' alias executes the LLM-provided bash command as a non-root user, and the 'saido' executes it as root.
#       - These aliases hide a backing function 'aido_func()' that includes a switch parameter to specify the user mode ('-a'=admin, '-u'=user).
#       - Note that if the LLM suggests 'sudo .. xyz ...' in its response, the function will strip the 'sudo' out if it is called by 'aido' or leave
#         it in if it is called by 'saido'.
#       - This is clearly a very rudamentary check (see 'SAFETY & SECURITY') and may result in the command not working if it requires root
#         privileges. Also, the user can always add 'sudo' to the command before executing it... again, see 'SAFETY & SECURITY' above!
#       - These risks could be mitigated somewhat by appending '... under the current user' to the prompt for 'aido' and by
#         scanning the user's edited command for 'sudo' before executing it (all of which is not implemented below).
#       - The function as a whole must be run as a non-root user so that the 'aichat' Python package & server can be run as
#         configured in the user's home directory (~/.cargo/bin/aichat), which is why switches are used. It will refuse to run as root.
#
# EXAMPLES :
#
#       aido 'create a new directory called xyz'
#           - the LLM model is asked to provide a bash command to create a new directory to be executed under the current user
#           - possible response: 'mkdir xyz'
#
#       saido 'create a new directory xyz'
#           - the LLM model is asked to provide a bash command to create a new directory, and the command is executed as root because of 
#             the implicit '-a' switch
#           - possible response: 'sudo mkdir xyz'
#
#       aido 'list files in the current directory'
#           - the LLM model is asked to provide a bash command to list files in the current directory
#           - possible response: 'ls'
#
#       [s]aido 'install a package called xyz'
#           - the LLM model is asked to provide a bash command to install the package xyz
#           - possible response: '[sudo] apt-get install xyz'
#
# SET-UP :
#
#       - Add these snippets to your .bashrc file to provide a handy way to request help from a LLM model to formulate bash commands
#         which you can then choose to edit and execute.
#       - Follow instructions provided elsewhere to install the 'aichat' package and the 'ollama' server with anLLM model
#
# DEPENDENCIES :
#
#       - The 'aichat' package is installed in the user's home directory. 'aichat' is a simple wrapper around the 'aichat' Python package that provides
#         chat functionality and a means of abstracting away how the LLM model is being served
#
#             Refer to: https://github.com/sigoden/aichat
#
#       - If a locally-hosted model is required or preffered, the 'ollama' server can be used. Alternatively, any other LLM model server (like LLM Studio)
#         should work, provided it plays nice with 'aichat'. Should a cloud-based solution be preferrable, OpenAI's API can be used, as well as the many
#         alternatives. Again, 'aichat' takes care of the details and therefore drives the available solution space
#
#             E.g., refer to: https://ollama.com, https://github.com/bentoml/OpenLLM, https://h2o.ai/platform/ai-cloud/make/llm-studio
#
# SHORTCOMINGS and CONSTRAINTS :
#
#       - The prompt that is used (see below) to ask the model for bash command may need to be optimized for the specific LLM model being used
#       - Clean-up of the LLM output is basic as implemented and may need to be improved for specific LLM models and to make more robust in general
#       - Only one comand recommendation is provided at a time (no ability to select from alternatives)
#       - No context is maintained between the user's prompt, the LLM's response, and the next user prompt/LLM response (no chaining)
#       - The rejection mechanism to not execute the suggested command is crude (Ctrl-C, etc.) and raises the possibility of the user
#         mistakenly executing a command they did not intend to
#
# TEST COVERAGE and LIMITATIONS :
#
#       - Tested with the ollama server running locally in Ubuntu and using Eric Hartford's dolphin-mixtral-8x7b model
#       - OpenAI GPT-x via API or other cloud hosted LLM models not tested
#       - Very little prompt engineering done to optimize the LLM's response
#
# POSSIBLE ALTERNATIVES:
#
#       - https://github.com/TheR1D/shell_gpt and many more
#

#
# The following are snippets to add to your .bashrc :
#
# ...

### ALIASES
#   Add the following code to your .bashrc file to create the 'aido' and 'saido' aliases:
#    -  First parameter: the name of the alias
#    -  Second parameter: the command to be aliased, with '-u' meaning user mode and '-a' meaning admin/sudo mode 
#    -  Third parameter: the verbosity of the output with '-v' meaning verbose and '-n' meaning non-verbose (mainly for debugging)
#    -  Fourth (implicit) parameter following the alias: the user's request to the LLM for a command
#   Example:     aido create a new directory called mydir in the current directory
#   Aliases to:  'aido_func aido -u -n create a new directory called mydir in the current directory'
#    -   Possible response from the LLM: 'mkdir mydir'
# Note that ALL parameters are MANADATORY and must be provided in the order given.
# With the usual caveats, the prompt can be entered on the CLI unquoted 
alias aido='aido_func aido -u -n'
alias saido='aido_func saido -a -n'

# ... miscellaneous .bashrc file contents ...

### FUNCTION
# Add the following code to your .bashrc file which is used by the 'aido' and 'saido' aliases
function aido_func() {

    # Set the Linux distribution and version to possibly improve the quality of the LLM response
    DISTRO="Ubuntu"
    VERSION="20.04"

    # This is the prefix to be used for prompting the LLM model so that it (hopefully) just provides an appropriate bash command
    # It should be re-engineered and optimized to get the best results from a particula LLM model
    # This version was used with dolphin-mixtral-8x7b with good results but I'm sure improvements can be made to it with some experimentation
    local STOCK_PRMT_PREFIX='you are an expert at using shell bash commands from a terminal CLI. I want you to provide me with the best command that will answer a question posed a little later in this prompt. But first note that I must be able to copy and paste your answer directly into the terminal without making any modifications to it.  It must be ready for me to just hit the Return key to run. So DO NOT provide me with any context or explanations and make sure your response is in plain text without any surrounding quotes or embeded markdown or backticks! If more than one bash command is needed or maybe even a small script give it all to me as single one-liner with semicolons and double ampersands as required but NO backslashes please. So here is my question which you will answer with bash command(s) all in one line: How do I'

    # DO NOT CHANGE BELOW THIS LINE
        
    # Check if the function is being run as root and exit if it is
    # The function should be run as non-root so that the 'aitchat' (and ollama) package & server
    # can be run as configured in the user's home directory (~/.cargo/bin/aichat)
    if [[ "$HOME" == *"root"* ]]; then
        echo "ERROR: Should not be run from root. Use the -a option to have the option to execute the LLM-provided bash command as root."
        return 1
    fi

    # Make sure at least four arguments are provided.  I say 'at least' because if the user's prompt is unquoted and contains spaces, 
    # it will be split by the shell into multiple arguments but that's ok because it will be reassembled into a single string
    # later on in this function
    local args=("$@")
    local num_args="${#args[@]}"
    if [ $num_args -lt 4 ]; then 
        echo "ERROR: missing arguments"
        echo "Usage: aido_func <invoking_alias> <user_mode> <verbose_opt> <user_prmt>"
        echo "   where: <invoking_alias> is the name of the alias or function that called this function"
        echo "          <user_mode> is '-a' for admin mode or '-u' for user mode"
        echo "          <verbose_opt> is '-v' for verbose output and '-n' for normal)"
        echo "          <user_prmt> is the user's prompt for the LLM"
        echo "   NOTE: ALL ARGUMENTS MUST BE PROVIDED AND ARE POSITION-SENSITIVE!"
        return 1
    fi

    # Extract the invoking alias name, the user mode switch, and the verbosity switch from the input arguments. The switches for user mode and
    # non-verbose output are not specifically checked; '-u' (user) and '-n' (normal) are suggested, respectively. The two switches MUST 
    # be provided so that their parameter order/positions are filled, all in the name of avoiding more complex parsing logic!
    # This should not be a hardship since aliases are used to call the function
    local invoking_alias="$1"
    shift
    local user_mode="$1"
    shift
    local verbose_opt="$1"
    shift

    # Reassemble the user's prompt from the remaining input arguments
    local old_ifs="$IFS"
    IFS=' '
    local user_prmt="$*"
    IFS="$old_ifs"
    
    # ANSI color codes used by debug output
    local RED='\033[1;91m'
    local GREEN='\033[0;32m'
    local BGREEN='\033[1;92m'
    local NC='\033[0m'

    # Determine if debug (aka verbose) output is enabled (-v); use any other value for normal operation but '-n' ("normal") is suggested
    local debug_func=false
    if [[ "$verbose_opt" == "-v" ]]; then
        debug_func=true
        echo
        echo -e "User prompt: ${GREEN}${user_prmt}${NC}"
        echo
        echo -e "Stock prompt: ${GREEN}${STOCK_PRMT_PREFIX}${NC}"
        echo
    fi

    # Create the augmented prompt by adding the user's prompt to the end of the stock prompt
    local aug_prmt="In the context of ${DISTRO} v${VERSION}, ${STOCK_PRMT_PREFIX} ${user_prmt}?"
    if [[ "$debug_func" == true ]]; then
        echo
        echo -e "Augmented user prompt: ${BGREEN}${aug_prmt}${NC}"
        echo
    fi

    # Create the command for the aichat and execute it. Any leading or trailing spaces, backticks etc. are removed from the LLM
    # output (which, despite prompt instructions to the contrary, may crop up in the output - at least they did with
    # dolphin-mixtral-8x7b.  This cleansing is far from robust as implemented, but it is a start.
    local pre_cmd="$HOME/.cargo/bin/aichat ${aug_prmt}"
    local COMMAND=$($pre_cmd)
    COMMAND=$(echo "$COMMAND" | sed 's/^[\` ]*//;s/[\` ]*$//' | awk 'NF {if(seen) printf ";"; seen=1; printf $aug_prmt}')

    if [[ "$debug_func" == true ]]; then
        echo
        echo -e "Output from LLM: ${RED}${COMMAND}${NC}"
        echo
    fi

    # Add 'sudo' to the new command if the user mode is '-a' (admin) AND it is not already present
    # Remove 'sudo' from the new command if the user mode is '-u' (user) and it is present; note that this could break the command
    # if it requires admin privileges
    if [[ "$user_mode" == "-a" ]]; then
        # Check if COMMAND starts with 'sudo ' and prepend 'sudo ' if not
        if [[ $COMMAND != sudo\ * ]]; then
            COMMAND="sudo $COMMAND"
        fi
    elif [[ "$user_mode" == "-u" ]]; then
        # If user mode is '-u' and COMMAND starts with 'sudo ', remove 'sudo '
        COMMAND="${COMMAND/#sudo /}"
    fi

    # Manually construct the command that was used to invoke the function and add it to history so the user can go back and edit/re-issue it
    local CMD_FOR_HISTORY="${invoking_alias} ${user_prmt}"
    history -s "$CMD_FOR_HISTORY"

    # Display the bash command at the command prompt so the user is able to interactively edit it in-line 
    # and choose to execute it by hitting [Enter].  Ctrl-C (sometimes Ctrl-D) will cancel editing and prevent execution.
    read -e -p "Edit & Execute hitting [Enter]: " -i "$COMMAND" EXECUTE

    # Execute the command!
    eval "$EXECUTE"

    # Add the executed command to history as well
    history -s "$EXECUTE"

    return 0
}
export -f aido_func

# the rest of your .bashrc file ...
