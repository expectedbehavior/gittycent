require 'active_support'
require 'active_support/all'
require 'httparty'
require 'pp'

class Gittycent
  API_VERSION = 'v2'
  FORMAT = 'yaml'
  NONE, WARNING, INFO, DEBUG = *1..10

  attr_accessor :options

  # Connects to GitHub using login/token. Yields or returns the new 
  # connection.
  #
  #  Gittycent.connect(:login => 'jqr', :token => 'somesecretstuff123')
  def self.connect(options)
    connection = new(options)
    if block_given?
      yield(connection)
    else
      connection
    end
  end

  # Simplified method for connecting with git config specified credentials.
  # Also allows for using an alternate section for easy handling of multiple
  # credentials. Just like connect this yields or returns the new connection.
  #
  #  gittycent = Gittycent.connect_with_git_config
  def self.connect_with_git_config(section = :github, options = {}, &block)
    config = Hash[*`git config -l`.scan(/^(.*?)=(.*)$/).flatten]
    connect(options.merge(:login => config["#{section}.user"], :token => config["#{section}.token"]), &block)
  end

  # Returns a new Gittycent connection object, requires :login and :token 
  # options.
  #
  #  gittycent = Gittycent.new(:login => 'jqr', :token => 'somesecretstuff123')
  def initialize(options)
    self.options = options
    debug "Login using login #{options[:login]} with token #{options[:token]}"
  end

  # Returns the verbosity level.
  def verbosity
    options[:verbosity] || NONE
  end

  # Finds a GitHub user by login.
  #
  #  user = gittycent.user('jqr')
  def user(login)
    if login == options[:login]
      AuthenticatedUser.new(self, :login => options[:login])
    else
      User.new(self, :login => login)
    end
  end

  # Finds GitHub users by a query string.
  def user_search(query)
    get("/user/search/#{query}")['users'].map { |u| User.new(self, u) }
  end

  # Returns the currently authenticated user.
  def authenticated_user
    @authenticated_user ||= user(options[:login])
  end

  def inspect # :nodoc:
    "#<#{self.class}#{' ' + options[:login] if options[:login].present?}>"
  end

  def default_http_options
    { 
      :query => {
        :login => options[:login],
        :token => options[:token]
      }
    }
  end

  # Performs a GET request on path, automatically prepending api version and 
  # format paramters. Will automatically retry if the request rate limiting is 
  # hit.
  def get(path)
    with_retry do
      url = "http://github.com/api/#{API_VERSION}/#{FORMAT}#{path}"
      debug "GET #{url}"
      response = HTTParty.get(url, default_http_options)
      debug response.code
      debug response.body
      debug
      response
    end
  end

  # Performs a POST request on path, automatically prepending api version and 
  # format paramters. Will automatically retry if the request rate limiting is 
  # hit.
  def post(path, params = {})
    with_retry do
      url = "http://github.com/api/#{API_VERSION}/#{FORMAT}#{path}"
      debug "POST #{url}"
      debug_inspect params
      response = HTTParty.post(url, default_http_options.deep_merge(:query => params))
      debug response.code
      debug response.body
      debug
      response
    end
  end

  def debug(message = "")
    puts message if verbosity >= DEBUG
  end

  def warn(message = "")
    puts message if verbosity >= WARNING
  end

  def debug_inspect(object)
    debug object.pretty_inspect
  end

  # Automatically retries a block of code if the returned value is rate 
  # limited (HTTP Code 403) by GitHub.
  def with_retry
    count = 0
    loop do
      response = yield
      if response.code == 403 && response['error'].any? { |e| e['error'] == 'too many requests' }
        count += 1
        delay = 2 ** count
        warn "too many requests, sleeping for #{delay} seconds"
        sleep delay
      else
        return response
      end
    end
  end

  class Connectable
    class_inheritable_accessor :identified_by
    attr_accessor :connection, :attributes
  
    def initialize(connection, options)
      self.connection = connection
      @attributes = options.symbolize_keys
      if self.class.identified_by && @attributes.include?(self.class.identified_by)
        send("#{identified_by}=", @attributes.delete(self.class.identified_by))
      end
      self.connection = connection
    end
  
    def get(*args)
      connection.get(*args)
    end
  
    def post(*args)
      connection.post(*args)
    end
  
    def debug(*args)
      connection.debug(*args)
    end
  
    def reload
      @attributes = {}
      load
    end
  
    def self.loadable_attributes(*attributes)
      (attributes - [identified_by]).each do |attribute|
        define_method(attribute) do
          if !@attributes.include?(attribute)
            load
          end
          @attributes[attribute]
        end
      end
    end
  
  end

  class User < Connectable
    attr_accessor :login
    self.identified_by = :login
  

    loadable_attributes :followers_count, :created_at, :company, :gravatar_id, 
       :public_repo_count, :location, :email, :public_gist_count, :blog, 
       :name, :following_count
  
    def to_s
      login.to_s
    end
  
    # Returns this user's repositories.
    def repos
      @repos ||= get("/repos/show/#{login}")['repositories'].map { |r| Repo.new(connection, r) }
    end
  
    def repo(name)
      Repo.new(connection, :name => name, :owner => self)
    end
  
    # Returns a list of all public repos thi user is watching.
    def watched_repos
      @repos ||= get("/repos/watched/#{login}")['repositories'].map { |r| Repo.new(connection, r) }
    end
  
    # Loads lazily-fetched attributes.
    def load
      @attributes = get("/user/show/#{login}")['user'].symbolize_keys
    end
  
    # Returns all the users that follow this user.
    def followers
      @followers ||= get("/user/show/#{login}/followers")['users'].map { |u| User.new(connection, :login => u) }
    end

    # Returns all the users that this user is following.
    def following
      @following||= get("/user/show/#{login}/following")['users'].map { |u| User.new(connection, :login => u) }
    end
    
    # Retrusns the url for viewing this user on the web.
    def url
      "http://github.com/#{login}"
    end
    
    def inspect # :nodoc:
      "#<#{self.class} #{login}>"
    end
  end

  class AuthenticatedUser < User
    loadable_attributes :owned_private_repo_count, :created_at,
      :private_gist_count, :plan, :collaborators, :disk_usage
    
    # Returns a list of all repos this user is watching.
    def watched_repos
      super
    end
  
    # Adds a new repository for this user. Supported options include: :name, 
    # :description, :homepage, :public.
    #
    #  repo = user.create_repo(:name => 'hello', :public => false)
    def create_repo(options)
      options = options.dup
      Repo.new(connection, post("/repos/create", options)['repository'])
    end
  end

  class Repo < Connectable
    attr_accessor :name
    self.identified_by = :name

    loadable_attributes :owner, :open_issues, :description, :fork, :forks, 
      :private, :url, :homepage, :watchers, :has_wiki, :has_downloads, :has_issues

    def to_s
      name.to_s
    end
  
    # Returns the owner of this repository.
    def owner
      @owner ||= User.new(connection, :login => @attributes[:owner])
    end
  
    # Returns a list of all collaborators.
    def collaborators
      @collaborators ||= get("/repos/show/#{owner.login}/#{name}/collaborators")['collaborators'] || []
    end
  
    # Sets the list of collaborators.
    def collaborators=(value)
      value = value.dup.uniq
      removals = collaborators - value
      additions = value - collaborators
      debug "removals: #{removals.join(', ')}"
      debug "additions: #{additions.join(', ')}"
      removals.each do |remove|
        post("/repos/collaborators/#{name}/remove/#{remove}")
      end
      additions.each do |addition|
        post("/repos/collaborators/#{name}/add/#{addition}")
      end
      @collaborators = nil
    end
  
    # Returns the shell commands used to do an initial push of this project to
    # GitHub.
    def initial_push_command
      "git remote add origin git@github.com:#{owner.login}/#{name}.git &&\n" +
      "git push origin master &&\n" +
      "git config --add branch.master.remote origin &&\n" +
      "git config --add branch.master.merge refs/heads/master" 
    end
  
    # Returns repositories in this repository's network.
    def network
      @network ||= get("/repos/show/#{owner.login}/#{name}/network")['network'].map { |r| Repo.new(connection, r) }
    end
  
    # Returns the languages detected.
    def languages
      get("/repos/show/#{owner.login}/#{name}/languages")['languages']
    end
  
    # Loads lazily-fetched attributes.
    def load
      @attributes = get("/repos/show/#{owner.login}/#{name}")['repository'].symbolize_keys
    end
  
    # Returns a single commit
    def commit(id)
      Commit.new(connection, { :id => id, :repo => self })
    end
  
    # Returns all tags of this repository.
    def tags
      @tags ||= get("/repos/show/#{owner.login}/#{name}/tags")['tags']
    end
  
    # Returns all branches of this repository.
    def branches
      @branches ||= get("/repos/show/#{owner.login}/#{name}/branches")['branches'].map do |name, head|
        Branch.new(connection, 
          :name => name,
          :head => head,
          :repo => self
        )
      end
    end
  
  end

  class Branch < Connectable
    attr_accessor :name, :head, :repo
    self.identified_by = :name
    
    # Returns all commits in this branch, most recent first.
    def commits
      if !@commits
        @commits = []
        x = 0
        loop do
          x += 1
          response = get("/commits/list/#{repo.owner.login}/#{repo.name}/#{name}?page=#{x}")
          break unless response.code == 200
          @commits += response['commits'].map { |c| Commit.new(connection, c.merge(:repo => self)) }
        end
      end
      @commits
    end
    
    # Returns the associated repository.
    def repo
      @attributes[:repo]
    end
    
    # Retrusns the url for viewing this branch on the web.
    def url
      "http://github.com/#{repo.owner.login}/#{repo.name}/#{name}"
    end
    
    def inspect # :nodoc:
      "#<#{self.class} #{url}>"
    end
  end

  class Commit < Connectable
    attr_accessor :id
    self.identified_by = :id

    loadable_attributes :author, :parents, :committed_date, :authored_date, :message, :committer, :tree, :modified

    def to_s
      id.to_s
    end
  
    # Returns the associated repository.
    def repo
      @attributes[:repo]
    end
  
    # Returns the parent commits of this commit.
    def parents
      load unless @attributes.include?(:parents)
      @parents ||= @attributes[:parents].map { |p| Commit.new(connection, p.merge(:repo => repo)) }
    end
  
    # Returns the Person who authored this commit.
    def author
      @author ||= Person.new(connection, @attributes[:author])
    end

    # Returns the Person who committed this commit.
    def committer
      @committer ||= Person.new(connection, @attributes[:committer])
    end
    
    def modifications
      @modifications ||= modified.map { |m| Modification.new(connection, self, m) }
    end
  
    def url
      "http://github.com/#{repo.owner.login}/#{repo.name}/commit/#{id}"
    end
    
    # Loads lazily-fetched attributes.
    def load
      @attributes = get("/commits/show/#{repo.owner.login}/#{repo.name}/#{id}")['commit'].symbolize_keys.merge(:repo => repo)
    end
  
    def inspect # :nodoc:
      "#<#{self.class} #{url}>"
    end
  end
  
  class Modification
    attr_accessor :connection, :commit, :filename, :diff
    
    def initialize(connection, commit, attributes)
      @connection = connection
      @commit = commit
      @filename = attributes['filename']
      @diff = attributes['diff']
    end
  end

  class Person < Connectable
    loadable_attributes :name, :email, :login

    def user
      if login
        connection.user(login)
      end
    end
  end
end
