# Degem

<div align="center">
  <img width="200" width="200" src=".github/images/degem.svg" />
</div>

<p></p>

Find unused gems in a Ruby bundle (ie, an app with a `Gemfile` or a gem with both a `Gemfile` and a gemspec).

Notice that, given the dynamic nature of Ruby, it's not possible to identify unused gems with confidence.

With the current heuristics, many false positives are reported. But we can [make it better](https://github.com/3v0k4/degem/issues).

**Review the reported unused gems carefully!**

## Users

<p>
  <a href="https://rictionary.odone.io">
    <img width="90" width="90" hspace="10" src=".github/images/rictionary.svg" />
  </a>

  <a href="https://knapsackpro.com">
    <img width="100" width="100" hspace="10" src=".github/images/knapsackpro.png" />
  </a>
</p>

## Usage

```bash
bundle add degem
bundle exec degem
```

The final report will look something like:

```
The following gems may be unused:

sqlite3: https://github.com/sparklemotion/sqlite3-ruby
======================================================

be4e37f (2024-11-15) deps: rails new to update files
https://github.com/3v0k4/rictionary/commit/be4e37ff7caddcc2bc1d00494d155371e2b1a7e4
9d9ea88 (2021-01-15) prep for heroku
https://github.com/3v0k4/rictionary/commit/9d9ea882231fe809acc28985d4c280d22c31469b
2f70e1c (2021-01-12) init
https://github.com/3v0k4/rictionary/commit/2f70e1c5b6b1ac5b058feb10eabbc6bf76cfb332


kamal: https://github.com/basecamp/kamal
========================================

be4e37f (2024-11-15) deps: rails new to update files
https://github.com/3v0k4/rictionary/commit/be4e37ff7caddcc2bc1d00494d155371e2b1a7e4


thruster: https://github.com/basecamp/thruster
==============================================

be4e37f (2024-11-15) deps: rails new to update files
https://github.com/3v0k4/rictionary/commit/be4e37ff7caddcc2bc1d00494d155371e2b1a7e4


debug: https://github.com/ruby/debug
====================================

be4e37f (2024-11-15) deps: rails new to update files
https://github.com/3v0k4/rictionary/commit/be4e37ff7caddcc2bc1d00494d155371e2b1a7e4
2f70e1c (2021-01-12) init
https://github.com/3v0k4/rictionary/commit/2f70e1c5b6b1ac5b058feb10eabbc6bf76cfb332
```

## Development

After checking out the repo, run `bin/setup` to install the dependencies. Then, run `bin/rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on [GitHub](https://github.com/3v0k4/degem).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
