# Scripts

A public collection of shell scripts maintained by [yqwd-dimleap](https://github.com/yqwd-dimleap) for common operational and development tasks. This repository provides a central place to discover, review, and download scripts.

## Project Status

The repository is being initialized. No scripts are available yet. Usage instructions and requirements will be documented as scripts are added.

## Getting Started

### Clone the Repository

```sh
git clone https://github.com/yqwd-dimleap/scripts.git
cd scripts
```

### Download an Individual Script

Once scripts are available, download them directly from GitHub. Replace `path/to/script.sh` with the actual repository path:

```sh
curl --fail --show-error --location \
  https://raw.githubusercontent.com/yqwd-dimleap/scripts/main/path/to/script.sh \
  --output script.sh
```

For reproducible downloads, replace `main` in the URL with a full commit SHA. Downloads from `main` reflect the latest version on that branch and may change over time.

### Run a Script

Read the script and its documentation before running it. Check its supported operating systems, required tools, configuration, and permissions.

For a script with a valid shebang specifying its interpreter:

```sh
chmod +x script.sh
./script.sh
```

Use the interpreter specified by each script; not every shell script is compatible with `sh` or `bash`. Run with elevated privileges only when explicitly required by the script's documentation.

## Script Documentation

Each script should document:

- Its purpose and expected behavior.
- Supported operating systems and required dependencies.
- Command-line arguments, environment variables, and usage examples.
- Required permissions and any changes it makes to files or system settings.

## Contributing

Issues and pull requests are welcome.

1. Open an issue to discuss substantial additions or changes.
2. Create a branch for your work.
3. Keep scripts focused, use descriptive filenames, and declare the intended interpreter with a shebang.
4. Include usage instructions and document dependencies and side effects.
5. Check shell syntax, run [ShellCheck](https://www.shellcheck.net/) where supported, and test in an appropriate environment.
6. Submit a pull request describing the change and how it was tested.

Keep documentation and code comments in English. Do not commit credentials, secrets, or company-internal information.

## Support

Use [GitHub Issues](https://github.com/yqwd-dimleap/scripts/issues) to report bugs or request scripts. Include the script name, operating system, shell version, steps to reproduce, and relevant output. Remove sensitive information from logs before sharing them.

## License

This project is licensed under the Apache License, Version 2.0. See [LICENSE](LICENSE) for the full license text.
