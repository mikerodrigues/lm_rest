# LMRest


## Installation

Add this line to your application's Gemfile:

```ruby
gem 'lm_rest'
```

And then execute:

`$ bundle`

Or install it yourself as:

`$ gem install lm_rest`



## Usage

See the example `ds_checker.rb` script in `bin` to get a better feel for how to
use the gem.

```ruby
require 'lm_rest'

lm = LMRest.new(company_name, user_id, password)



# returns array of Datasource objects
#
lm.get_datasources


# get a datasource by id
lm.get_datasource(721)

# return array of Datasource objects whose names begin with "VMware"
#
lm.get_datasources(filter: 'name:VMware*')

```


## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).


## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/mikerodrigues/lm_rest.
