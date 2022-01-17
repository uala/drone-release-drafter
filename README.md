# Drone Release Drafter

This [drone plugin](https://drone.io/) can be used to draft releases for a GitHub repository.

Plugin in action:

```console
I, [2022-01-09T13:22:02.324389 #6]  INFO -- : Plugin configuration: {"changelog"=>{"categories"=>[{"labels"=>["new feature", "enhancement"], "title"=>"New Features"}, {"labels"=>["bugfix"], "title"=>"Bugfixes"}, {"labels"=>["dependencies"], "title"=>"Dependencies update"}, {"labels"=>["*"], "title"=>"Other Changes"}]}, "version_resolver"=>{"calver"=>{"format"=>"$YEAR.$MONTH-$MICRO", "month"=>"%m", "year"=>"%y"}}}
I, [2022-01-09T13:22:02.324428 #6]  INFO -- : Drafting release for main branch...
I, [2022-01-09T13:22:04.537364 #6]  INFO -- : Merged pull requests from release 22.01-1: ["Pull request 4", "Pull request 1", "Pull request 2", "Pull request 3"]
I, [2022-01-09T13:22:04.537612 #6]  INFO -- : New drafting tag name details:
Tag: 22.01-2
Body:
<!-- Release notes generated using Drone plugin -->

## What's Changed
### New Features
* Pull request 4 by @user1 in https://github.com/test/test/pull/4
* Pull request 2 by @user2 in https://github.com/test/test/pull/2
### Bugfixes
* Pull request 1 by @user1 in https://github.com/test/test/pull/1
### Dependencies update
* Pull request 3 by @user3 in https://github.com/test/test/pull/3


**Full Changelog**: https://github.com/test/test/compare/22.01-1...22.01-2

I, [2022-01-09T13:22:05.816372 #6]  INFO -- : Drafted release 22.01-2: https://github.com/test/test/releases/tag/untagged-0
```

## Usage

In order to use this plugin in one your Drone steps you can use the following step definition:

```yaml
steps:
  - name: draft
    image: uala/drone-release-drafter
    pull: if-not-exists
    environment:
      GITHUB_PUBLISH_TOKEN: ''
    settings:
      changelog:
        categories:
          - title: New Features
            labels:
              - new feature
              - enhancement
          - title: Bugfixes
            labels:
              - bugfix
          - title: Dependencies update
            labels:
              - dependencies
          - title: Other Changes
            labels:
              - "*"
      version_resolver:
        calver:
          year: '%y'
          month: '%m'
          format: '$YEAR.$MONTH-$MICRO'
      branches:
        - main
      enforce_head: true
      release_labels:
        - automatic release
```

Plugin image will read the given config and draft (create or update) a new release.

*Please note that it's required for an existing release to be already present on the repository, in order to properly resolve the new changelog and version.*

### GitHub token

A GitHub OAuth token must be passed to the plugin through the `GITHUB_PUBLISH_TOKEN` environment variable. Due to the not-so-fine-grained GitHub permissions, given token must have read and write permissions to the whole repository.

### Plugin settings

The plugin accepts the following settings:

* `changelog`: mandatory setting, contains release changelog settings as per [GitHub release configuration](https://docs.github.com/en/repositories/releasing-projects-on-github/automatically-generated-release-notes#configuration-options)
* `dry_run`: setting this value to any non empty string will enable plugin dry-run mode, i.e. commands will printed to screen but they won't be executed
* `logging`: logging level of plugin, default is `info`, supported values: [any Ruby logger valid level](https://ruby-doc.org/stdlib-2.4.0/libdoc/logger/rdoc/Logger.html#class-Logger-label-Description)
* `version_resolver`: object describing how to resolve next release tag/name
* `branches`: array of branches' names where the plugin should run, an empty field means all branches are enabled
* `enforce_head`: boolean any non empty string will be considered as true, will skip plugin logic if not on HEAD commit
* `release_labels`: array of labels that will trigger automatic release if all merged pulls contains at least one of the specified labels

#### Changelog

The changelog's categories order respect the defined order in configuration. As per Pull Request order inside a category, the `merged_at` field is used, sorting from the least recent merged to the most recent one.

#### Version resolver

The plugin is currently configurable for [CalVer](https://calver.org/) versioning, with `year`, `month`, `day` calendar variables (in [ISO-8601 format](https://apidock.com/ruby/Time/strftime)) and `micro` versioning variable.

Accepted options are:

* `year`: year format
* `month`: month format
* `day`: day format
* `format`: tag/name string format composable with `$YEAR`, `$MONTH`, `$DAY`, `$MICRO` variables in the preferred format

For example, given the configuration above and the latest version named `21.10-4`, this plugin will resolve new version tag/name as `21.10-5` while we are in Oct '21, `21.11-0` while we are in Nov '21 and `22.01-0` while we are in Jan '22.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/uala/drone-release-drafter

## License

Drone Release Drafter is released under the [MIT License](https://opensource.org/licenses/MIT).
