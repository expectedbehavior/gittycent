require 'active_support'
require 'active_support/all'
require 'httparty'
require 'pp'

class GitHub
  API_VERSION = 'v2'
  FORMAT = 'yaml'
  NONE, WARNING, INFO, DEBUG = *1..10
  
  attr_accessor :options
  
  def self.connect(options)
    connection = new(options)
    if block_given?
      yield(connection)
    else
      connection
    end
  end
  
  def self.connect_with_git_config(section = :github, options = {}, &block)
    config = Hash[*`git config -l`.scan(/^(.*?)=(.*)$/).flatten]
    connect(options.merge(:login => config["#{section}.user"], :token => config["#{section}.token"]), &block)
  end
  
  def initialize(options)
    self.options = options
    debug "Login using login #{options[:login]} with token #{options[:token]}"
  end
  
  def verbosity
    options[:verbosity] || NONE
  end
  
  def user(login)
    if login == options[:login]
      AuthenticatedUser.new(self, :login => options[:login])
    else
      User.new(self, :login => login)
    end
  end
  
  def user_search(query)
    get("/user/search/#{query}")['users'].map { |u| User.new(self, u) }
  end

  def authenticated_user
    @authenticated_user ||= user(options[:login])
  end
  
  def inspect
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
    attr_accessor :connection, :name
    
    def initialize(connection, options)
      self.connection = connection
      @attributes = options.dup
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
    
    loadable_attributes :created_at, :gravatar_id, :public_repo_count, 
      :public_gist_count, :following_count, :followers_count
    
    def to_s
      login.to_s
    end
    
    def repos
      @repos ||= get("/repos/show/#{login}")['repositories'].map { |r| Repo.new(connection, r) }
    end
    
    def watched_repos
      @repos ||= get("/repos/watched/#{login}")['repositories'].map { |r| Repo.new(connection, r) }
    end
    
    # supported options include: :name, :description, :homepage, :public
    def create_repo(options)
      options = options.dup
      Repo.new(connection, post("/repos/create", options)['repository'])
    end
    
    def load
      @attributes = get("/user/show/#{login}")['user'].symbolize_keys
    end
    
    def followers
      @followers ||= get("/user/show/#{login}/followers")['users'].map { |u| User.new(connection, :login => u) }
    end

    def following
      @following||= get("/user/show/#{login}/following")['users'].map { |u| User.new(connection, :login => u) }
    end
  end
  
  class AuthenticatedUser < User
    loadable_attributes :followers_count, :owned_private_repo_count, 
      :created_at, :company, :private_gist_count, :plan, :gravatar_id, 
      :total_private_repo_count, :public_repo_count, :location, :email, 
      :collaborators, :public_gist_count, :blog, :name, :following_count, 
      :disk_usage
  end
  
  class Repo < Connectable
    attr_accessor :name
    self.identified_by = :name

    loadable_attributes :owner, :open_issues, :description, :fork, :forks, 
      :private, :url, :homepage, :watchers

    def to_s
      name.to_s
    end
    
    def owner
      @owner ||= User.new(connection, :login => @attributes[:owner])
    end
    
    def collaborators
      @collaborators ||= get("/repos/show/#{owner.login}/#{name}/collaborators")['collaborators'] || []
    end
    
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
    
    def initial_push_command
      "git remote add origin git@github.com:#{owner.login}/#{name}.git &&\n" +
      "git push origin master &&\n" +
      "git config --add branch.master.remote origin &&\n" +
      "git config --add branch.master.merge refs/heads/master" 
    end
    
    def network
      @network ||= get("/repos/show/#{owner.login}/#{name}/network")['network'].map { |r| Repo.new(connection, r) }
    end
    
    def languages
      get("/repos/show/#{owner.login}/#{name}/languages")['languages']
    end
    
    def tags
      get("/repos/show/#{owner.login}/#{name}/tags")['tags']
    end
    
    def branches
      get("/repos/show/#{owner.login}/#{name}/branches")['branches']
    end
  end
end