require 'spec_helper'

describe "GitHub" do
  before(:each) do
    @gh = GitHub.connect(:login => 'login', :token => 'token', :verbosity => GitHub::NONE)
  end
  
  it "should return the authenticated user" do
    @gh.authenticated_user.should be_an_instance_of(GitHub::AuthenticatedUser)
    @gh.authenticated_user.login.should == 'login'
  end
  
  it "should be able to find the authenticated user by login" do
    @gh.user('login').should be_an_instance_of(GitHub::AuthenticatedUser)
    @gh.user('login').login.should == 'login'
  end
  
  describe "User" do
    before(:each) do
      @owner = @gh.authenticated_user
    end
    
    describe "following" do
      before(:each) do
        response = "
          ---
          users: 
          - netshade
          - kristopher
          - sephonicus
        "
        FakeWeb.register_uri(:get, %r{http://github.com/api/v2/yaml/user/show/login/following?.*}, 
          :content_type => 'text/yaml',
          :body => response
        )
      end
      
      it "should list followings" do
        @owner.following.map(&:login).should include('netshade', 'kristopher', 'sephonicus')
      end
    end

    describe "followers" do
      before(:each) do
        response = "
          ---
          users: 
          - netshade
          - kristopher
          - sephonicus
        "
        FakeWeb.register_uri(:get, %r{http://github.com/api/v2/yaml/user/show/login/followers?.*}, 
          :content_type => 'text/yaml',
          :body => response
        )
      end
      
      it "should list followers" do
        @owner.followers.map(&:login).should include('netshade', 'kristopher', 'sephonicus')
      end
    end
    
    describe "repos" do
      before(:each) do
        response = "
          ---
          repositories: 
          - :description: Some silly repository.
            :has_issues: true
            :watchers: 1
            :forks: 2
            :has_wiki: true
            :homepage: http://somewhere.com
            :fork: false
            :open_issues: 3
            :url: http://github.com/login/silly_repo
            :private: false
            :name: silly_repo
            :owner: login
            :has_downloads: false
          - :description: DUH
            :has_issues: true
            :watchers: 4
            :forks: 5
            :has_wiki: true
            :homepage: ""
            :fork: false
            :open_issues: 6
            :url: http://github.com/login/duh
            :private: false
            :name: duh
            :owner: login
            :has_downloads: true
        "
        FakeWeb.register_uri(:get, %r{http://github.com/api/v2/yaml/repos/show/login?.*}, 
          :content_type => 'text/yaml',
          :body => response
        )
      end
    
      it "should list repositories" do
        @owner.repos.map(&:name).should include('silly_repo', 'duh')
      end
    
      it "should capture description" do
        @owner.repos.first.description.should == 'Some silly repository.'
      end
    
      it "should capture has_issues" do
        @owner.repos.first.has_issues.should == true
      end
    
      it "should capture watchers" do
        @owner.repos.first.watchers.should == 1
      end
    
      it "should capture forks" do
        @owner.repos.first.forks.should == 2
      end
    
      it "should capture has_wiki" do
        @owner.repos.first.has_wiki.should == true
      end
    
      it "should capture homepage" do
        @owner.repos.first.homepage.should == 'http://somewhere.com'
      end
    
      it "should capture fork" do
        @owner.repos.first.fork.should == false
      end
    
      it "should capture open_issues" do
        @owner.repos.first.open_issues.should == 3
      end
    
      it "should capture url" do
        @owner.repos.first.url.should == 'http://github.com/login/silly_repo'
      end
    
      it "should capture private" do
        @owner.repos.first.private.should == false
      end
    
      it "should capture name" do
        @owner.repos.first.name.should == 'silly_repo'
      end
    
      it "should capture owner" do
        @owner.repos.first.owner.login.should == 'login'
      end
    
      it "should capture has_downloads" do
        @owner.repos.first.has_downloads.should == false
      end
    end
  end
end