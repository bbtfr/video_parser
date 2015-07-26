Video Parser
===

Installation
---

1. Download [ml-latest.zip](https://grouplens.org/datasets/movielens/) and unzip it;
2. Download [browsermob-proxy](http://bmp.lightbody.net/) and unzip it;
3. Make sure you have `Firefox` installed;
3. Make sure you have ruby 1.9.3+ installed and `gem install bundler`;
4. `bundle install` to install all the gem vendors;
5. Edit `parser.rb`: `ENV["CSV_PATH"]`, `ENV["JAVA_HOME"]` and `ENV["BROWSER_MOB_PROXY"]` to your `ml-lastest` path, java home path and `browsermob-proxy` path;
6. `ruby parser.rb` you are ready to go.
