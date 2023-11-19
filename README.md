# deploy_php
This scripts that I use for life with local projects

## Overview

This Bash script facilitates the creation and deletion of projects along with configuring Apache settings and MySQL databases for a development environment.

## Requirements

Ensure that the following utilities are installed before executing the script:

    * git
    * openssl
    * sudo
    * systemctl
    * mysql
    * service
    * a2ensite
    * a2dissite

Before usinf you need to setup the script.

## Usage

```bash
$ ./deploy_project.sh project_name action [git_repo]
```

## Examples

Create a project:

```bash
$ ./deploy_project.sh create my_project_name https://github.com/username/my_project.git
```

Delete a project:
```bash
$ ./deploy_project.sh delete my_project_name
```

### Arguments

    * project_name: The name of the project.
    * action: The action to perform, either create or delete.
    * git_repo (optional): The Git repository URL (for SSH project creation).

## Configuration

    * MySQL: Ensure that the MYSQL_USER and MYSQL_PASSWORD variables are correctly configured in the script.
    * Apache: Adjust the APACHE_SERVICE, SITES_AVAILABLE, and ADDRESS_SUFFIX variables as per your Apache configuration.
    * Project Root Directory: Modify the PROJECTS_ROOT variable to define the root directory for your projects.

## Functionality

### Create Action:
    * Sets up MySQL database and user.
    * Clones the project from Git repository (if provided) and configures Apache settings (add VirtualHost and add record to hosts file).
    * Provides instructions and paths for the created project.

### Delete Action:
    * Removes project-related directories and remove VirtualHost Apache settings.
    * Deletes the MySQL database and associated database user.

## Note

    * The script checks for the necessary utilities and prerequisites before execution.
    * Modify the script variables to align with your system configuration before usage.
