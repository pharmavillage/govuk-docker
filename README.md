# GOV.UK Docker

GOV.UK development environment using Docker.

![diagram](docs/diagram.png)

The GOV.UK website uses a microservice architecture. Developing in this ecosystem is a challenge, due to the range of environments to maintain, both for the app being developed and its dependencies.

The aim of govuk-docker is to make it easy to develop any GOV.UK app. It achieves this by providing a variety of environments or _stacks_ for each app, in which you can run tests, start a debugger, publish a document end-to-end.

[RFC 106: Use Docker for local development](https://github.com/alphagov/govuk-rfcs/blob/master/rfc-106-docker-for-local-development.md) describes the background for choosing Docker. See the [list of services which work with govuk-docker](docs/compatibility.md).

## Installation

[Instructions for how to install and setup govuk-docker are here.](docs/installation.md)

## Usage

Do this to run the tests for a service:

```sh
make collections-publisher

cd ~/govuk/collections-publisher

govuk-docker run collections-publisher-lite bundle exec rake
```

Do this to start a GOV.UK web app:

```sh
make collections-publisher

cd ~/govuk/collections-publisher

# Start collections-publisher including dependencies.
# Visit it at collections-publisher.dev.gov.uk
govuk-docker up collections-publisher-app
```

For a full list of govuk-docker commands, run `govuk-docker help`.

## Stacks

Each service provides a number of different 'stacks' which you can use to run
the app. You can see the stacks for a service in its [config file](services/content-publisher/docker-compose.yml).
To provide consistency we have a convention for these names:

- **lite**: This stack provides only the minimum number of dependencies to run
  the application code. This is useful for running the tests, or a Rails
  console, for example. It won't be useful for opening the app in a browser.
- **app**: This stack provides the dependencies necessary to run the app in the
  browser. Variations on this are allowed where necessary such as:
  - **app-draft**: if the application uses the content-store, this stack will
    point to the [draft content-store](https://docs.publishing.service.gov.uk/manual/content-preview.html).
  - **app-live**: if the app is a read-only frontend app, the live stack will
    point the production versions of content-store and search-api.
  - **app-e2e**: to run the app with all the other apps necessary to provide
    full end to end user journeys.

### Interoperability of stacks

Even if an e2e stack is started, functionality won't necessarily work as expected "end to end" as govuk-docker doesn't mimick the routing we have on GOV.UK. For example, publishing apps that link to draft-origin.dev.gov.uk frontends will see a server error, as draft-origin isn't a service in govuk-docker.

In these cases, you can swap out the URL for the relevant frontend (such as draft-collections.dev.gov.uk). It's also worth noting that this frontend will need to be started separately, as publishing apps don't define frontend apps in their Docker service dependencies; a publishing app doesn't need its corresponding frontend in order to be able to publish.

## How to's

### How to: diagnose and troubleshoot

Sometimes things go wrong or some investigation is needed. As govuk-docker is just a bunch of docker config and a CLI wrapper, it's still possible to use all the standard docker commands to help fix issues and get more info e.g.

```
# make sure govuk-docker is up-to-date
git pull

# make sure the service is built OK
make -f <service>

# tail logs for running services
govuk-docker logs -f

# get all the running containers
docker ps -a

# get a terminal inside a service
govuk-docker run <service>-lite bash
```

### How to: update everything!

Sometimes it's useful to get all changes for all repos e.g. to support finding things with a govuk-wide grep. This can be done by running:

```
make pull
```

### How to: clear your Docker containers

Sometimes a service just doesn't work as expected, and the easiest thing to do is to start over. This command stops and removes all local govuk Docker containers:

```
govuk-docker rm -sv
```

You should then be able to `govuk-docker build` your service and have confidence you're not suffering from configuration drift.

### How to: work with local gems

Provide a local gem path relative to the location of the Gemfile you're editing:

```ruby
gem 'govuk_publishing_components', path: '../govuk_publishing_components'
```

### How to: replicate data locally

There may be times when a full database is required locally.  The following sections give examples of how to replicate this data from integration.  All examples require pv, which can be installed on a Mac using Brew (`brew install pv`).

#### MySQL

1. Download the relevant database dump from the [AWS S3 Bucket](https://s3.console.aws.amazon.com/s3/buckets/govuk-integration-database-backups/mysql/?region=eu-west-1&tab=overview)

2. Drop and recreate any existing database, e.g. for Whitehall:

```
govuk-docker up -d mysql
govuk-docker run mysql mysql -h mysql -u root --password=root -e "DROP DATABASE IF EXISTS whitehall_development"
govuk-docker run mysql mysql -h mysql -u root --password=root -e "CREATE DATABASE whitehall_development"
```

3. Import the file into the local MySQL database, e.g. for Whitehall:

```
pv whitehall_production.dump.gz | gunzip | govuk-docker run mysql mysql -h mysql -u root --password=root whitehall_development
```

#### PostgreSQL

1. Download the relevant database dump from the [AWS S3 Bucket](https://s3.console.aws.amazon.com/s3/buckets/govuk-integration-database-backups/postgres/?region=eu-west-1&tab=overview)

2. Drop and recreate any existing database, e.g. for Publishing API:

```
govuk-docker up -d postgres
govuk-docker run postgres /usr/bin/psql -h postgres -U postgres -c 'DROP DATABASE IF EXISTS "publishing-api"'
govuk-docker run postgres /usr/bin/createdb -h postgres -U postgres publishing-api
```

3. Import the file into the local Postgres database, e.g. for Publishing API:

```
pv publishing_api_production.dump.gz  | gunzip | govuk-docker run postgres /usr/bin/psql -h postgres -U postgres -qAt -d publishing-api
```

#### MongoDB

1.  Download the relevant database dump from the [AWS S3 Bucket](https://s3.console.aws.amazon.com/s3/buckets/govuk-integration-database-backups/mongodb/daily/mongo/?region=eu-west-1&tab=overview)

2. Unzip the archive, e.g. for Content Store:

```
gunzip mongodump-2019-08-12_0023.tgz
```

Or if it's a TAR file, you can extract a specific file or directory.  Using the Content Store as an example:
```
tar -xvzf mongodump-2019-08-12_0023.tar var/lib/mongodb/backup/mongodump/content_store_production -C directory_for_download
```

3. Update the `docker-compose.yml` file to mount your local directory into the VM, e.g.

```
  mongo:
    image: mongo:2.4
    volumes:
      - mongo:/data/db
      - /Path/To/Downloads/directory_for_download:/import
    ports:
      - "27017:27017"
      - "27018:27018"
```

4. Import the backup files into the local Mongo database, e.g. for Content Store:

```
govuk-docker up -d mongo
govuk-docker run mongo mongorestore --drop --db content-store /import/var/lib/mongodb/backup/mongodump/content_store_production/
```

### How to: set environment variables

While most environment variables should be set in the config for a service, sometimes it's necessary to set assign one or more variables at the point of running a command, such as a Rake task. This can be done using `env` e.g.

```
govuk-docker run content-publisher-lite env MY_VAR=my_val bundle exec rake my_task
```

### How to: install a new release of Ruby

Many of our services use a `.ruby-version` file in conjunction with `rbenv`. When a new version of Ruby is released and we start upgrading our services, you may start seeing the following error when you run commands.

```
ruby-build: definition not found: x.y.z
```

Most of our services share a common Docker image, which needs rebuilding to be aware of the new Ruby version. To fix the error, run the following commands, replacing '<service>' with the name of the service, e.g. 'collections-publisher'.
```
govuk-docker build --no-cache <service>-lite

# in the govuk-docker directory
make <service>
```

## Licence

[MIT License](LICENCE)
