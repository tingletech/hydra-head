require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe Hydra::FileAssetsController do
  include Devise::TestHelpers

  before do
    session[:user]='bob'
  end

  it "should be restful" do
    { :get => "/hydra/file_assets" }.should route_to(:controller=>'hydra/file_assets', :action=>'index')
    { :get => "/hydra/file_assets/3" }.should route_to(:controller=>'hydra/file_assets', :action=>'show', :id=>"3")
    { :delete=> "/hydra/file_assets/3" }.should route_to(:controller=>'hydra/file_assets', :action=>'destroy', :id=>"3")
    { :put=>"/hydra/file_assets/3" }.should route_to(:controller=>'hydra/file_assets', :action=>'update', :id=>"3")
    { :get => "/hydra/file_assets/3/edit" }.should route_to(:controller=>'hydra/file_assets', :action=>'edit', :id=>"3")
    { :get =>"/hydra/file_assets/new" }.should route_to(:controller=>'hydra/file_assets', :action=>'new')
    { :post => "/hydra/file_assets" }.should route_to(:controller=>'hydra/file_assets', :action=>'create')
    
  end
  
  describe "index" do
    
    it "should find all file assets in the repo if no container_id is provided" do
      ActiveFedora::SolrService.expects(:query).with('active_fedora_model_s:FileAsset', {}).returns("solr result")
      controller.stubs(:load_permissions_from_solr)
      ActiveFedora::Base.expects(:new).never
      xhr :get, :index
      assigns[:solr_result].should == "solr result"
    end
    it "should find all file assets belonging to a given container object if container_id or container_id is provided" do
      mock_container = mock("container")
      mock_container.expects(:file_objects).with(:response_format => :solr).returns("solr result")
      controller.expects(:get_search_results).with(:q=>'is_part_of_s:info\:fedora/_PID_').returns(["assets solr response","assets solr list"])
      controller.expects(:get_solr_response_for_doc_id).with('_PID_').returns(["container solr response","container solr doc"])
      controller.stubs(:load_permissions_from_solr)
      
      ActiveFedora::Base.expects(:find).with("_PID_", :cast=>true).returns(mock_container)
      xhr :get, :index, :asset_id=>"_PID_"
      assigns[:response].should == "assets solr response"
      assigns[:document_list].should == "assets solr list"
      
      assigns[:container_response].should == "container solr response"
      assigns[:document].should == "container solr doc"
      assigns[:solr_result].should == "solr result"
      assigns[:container].should == mock_container
    end
    
  end

  describe "new" do
    it "should set :container_id to value of :container_id if available" do
      xhr :get, :new, :asset_id=>"_PID_"
      @controller.params[:asset_id].should == "_PID_"
    end
  end

  describe "show" do
    it "should redirect to index view if current_user does not have read or edit permissions" do
      mock_user = mock("User")
      mock_user.stubs(:email).returns("fake_user@example.com")
      mock_user.stubs(:is_being_superuser?).returns(false)
      controller.stubs(:current_user).returns(mock_user)
      get(:show, :id=>"hydrangea:fixture_file_asset1")
      response.should redirect_to(:action => 'index')
    end
    it "should redirect to index view if the file does not exist" do
      get(:show, :id=>"example:invalid_object")
      response.should redirect_to(:action => 'index')
    end
  end
  
  describe "create" do
    it "should create and save a file asset from the given params" do
      mock_fa = mock("FileAsset")
      mock_file = mock("File")
      mock_fa.stubs(:pid).returns("foo:pid")
      controller.expects(:create_and_save_file_assets_from_params).returns([mock_fa])
      xhr :post, :create, :Filedata=>[mock_file], :Filename=>"Foo File"
    end
    it "if container_id is provided, should associate the created file asset wtih the container" do
      stub_fa = stub("FileAsset", :save)
      stub_fa.stubs(:pid).returns("foo:pid")
      stub_fa.stubs(:label).returns("Foo File")
      mock_file = mock("File")
      controller.expects(:create_and_save_file_assets_from_params).returns([stub_fa])
      controller.expects(:associate_file_asset_with_container)      
      xhr :post, :create, :Filedata=>[mock_file], :Filename=>"Foo File", :container_id=>"_PID_"
    end
    it "should redirect back to edit view if no Filedata is provided but container_id is provided" do
      controller.expects(:model_config).at_least_once.returns(controller.workflow_config[:mods_assets])
      xhr :post, :create, :container_id=>"_PID_", :wf_step=>"files"
      response.should redirect_to edit_catalog_path("_PID_", :wf_step=>"permissions")
      request.flash[:notice].should == "You must specify a file to upload."
    end
    it "should display a message that you need to select a file to upload if no Filedata is provided" do
      xhr :post, :create
      request.flash[:notice].include?("You must specify a file to upload.").should be_true
    end
    
  end

  describe "destroy" do
    it "should delete the asset identified by pid" do
      mock_obj = mock("asset", :delete)
      ActiveFedora::Base.expects(:find).with("__PID__", :cast=>true).returns(mock_obj)
      delete(:destroy, :id => "__PID__")
    end
    it "should remove container relationship and perform proper garbage collection" do
      pending "relies on ActiveFedora implementing Base.file_objects_remove"
      mock_container = mock("asset")
      mock_container.expects(:file_objects_remove).with("_file_asset_pid_")
      FileAsset.expects(:garbage_collect).with("_file_asset_pid_")
      ActiveFedora::Base.expects(:find).with("_container_pid_", :cast=>true).returns(mock_container)
      delete(:destroy, :id => "_file_asset_pid_", :asset_id=>"_container_pid_")
    end
  end
  
  describe "integration tests - " do
    before(:all) do
      class TestObj < ActiveFedora::Base
        include ActiveFedora::FileManagement
      end

      ActiveFedora::SolrService.register(ActiveFedora.solr_config[:url])
      @test_container = TestObj.new
      @test_container.add_relationship(:is_member_of, "info:fedora/foo:1")
      @test_container.add_relationship(:has_collection_member, "info:fedora/foo:2")
      @test_container.save
      
      @test_fa = FileAsset.new
      @test_fa.add_relationship(:is_part_of, @test_container)
      @test_fa.save
    end

    after(:all) do
     @test_container.delete
     @test_fa.delete
     Object.send(:remove_const, :TestObj)
    end

    describe "index" do
      it "should retrieve the container object and its file assets" do
        #xhr :get, :index, :container_id=>@test_container.pid
        get :index, {:asset_id=>@test_container.pid}
        @controller.params[:asset_id].should_not be_nil
        assigns(:solr_result).should_not be_nil
        #puts assigns(:solr_result).inspect
        assigns(:container).file_objects(:response_format=>:id_array).should include(@test_fa.pid)
        assigns(:container).file_objects(:response_format=>:id_array).should include("foo:2")
      end
    end
    
    describe "create" do
      before :each do
        mock_user = mock("User")
        mock_user.stubs(:email).returns('user@example.com')
        mock_warden = mock("Warden")
        mock_warden.stubs(:authenticate).returns(mock_user)
        request.env['warden'] = mock_warden
      end

      it "should set is_part_of relationship on the new File Asset pointing back at the container" do
        test_file = fixture_file_upload('/small_file.txt', 'text/plain')
        filename = "My File Name"
        post :create, {:Filedata=>[test_file], :Filename=>filename, :container_id=>@test_container.pid}
        assigns(:file_asset).ids_for_outbound(:is_part_of).should == [@test_container.pid] 
        retrieved_fa = FileAsset.find(@test_fa.pid).ids_for_outbound(:is_part_of).should == [@test_container.pid]
      end
    end
  end
end
