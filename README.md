# "AI do!" (aido) & "sudo AI do!" (saido)

Bash scripts for in-line CLI review, editing and execution of Bash commands suggested by an LLM in response to a user's requests for assistance.

- `aido` and `saido` are Bash aliases leveraging a backing function designed to execute Bash commands that have been suggested by an LLM (Language Model) based on natural language user prompts. 
- These tools integrate seamlessly into your `.bashrc` file, providing an in-line method to request Bash command guidance.

## Purpose

`aido` and `saido` are designed to provide users with a convenient interface for executing Bash commands as either a non-root user or as root, respectively, as suggested by a Language Learning Model (LLM). They serve as handy tools for those who may not remember every Bash command or who seek a targeted and actionable reminder without any tl;dr.

## Safety & Security

Users must manually approve and can modify any LLM-suggested command before execution. This measure ensures control and conscious user consent before any command execution, particularly for those prefixed by `sudo`. However, please note that this is a proof-of-concept and that users are wholly responsible for commands they execute, especially since `eval` is used for execution.

## Usage

Add the following aliases to your `.bashrc` to use (these are provided in the aido-bashrc-snippet.sh):

```bash
alias aido='aido_func aido -u'
alias saido='aido_func saido -a'
```

## Setup

Ensure the `aichat` package and any required LLM servers (like `ollama`) or cloud API services are properly configured on your machine. Add the provided function and aliases to your `.bashrc` file to enable the functionality.

## Dependencies

This script relies on the `aichat` package for LLM communication and might require local or remote LLM servers depending on your setup.

Refer to:

- `aichat` installation: [aichat GitHub page](https://github.com/sigoden/aichat)
- `ollama` server setup: [Ollama Homepage](https://ollama.com)

## Shortcomings and Constraints

The script may require prompt optimization for specific LLM models and does not support multiple command recommendations or maintain context between interactions.

## Test Coverage and Limitations

Currently tested with the `ollama` server and Eric Hartford's `dolphin-mixtral-8x7b` model. Other models and extensive prompt engineering have not been tested.

## Possible Alternatives

Explore other integrations like [Shell GPT](https://github.com/TheR1D/shell_gpt).

## License

This project is open-sourced under the MIT License. See the LICENSE file for details.

## Contributing

Contributions are welcome! 

## Disclaimer

This project is for educational and proof-of-concept purposes only. No guarantees are provided regarding the safety, security, or suitability of the suggested commands. Users are responsible for reviewing and executing commands at their own risk.
