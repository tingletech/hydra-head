require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')
require "active_fedora"

describe AudioAsset do
  
  before(:each) do
#    Fedora::Repository.stubs(:instance).returns(stub_everything())
    @asset = AudioAsset.new
    @asset.stubs(:create_date).returns("2008-07-02T05:09:42.015Z")
    @asset.stubs(:modified_date).returns("2008-09-29T21:21:52.892Z")
  end
  
  it "Should be a kind of ActiveFedora::Base kind of FileAsset, and instance of AudioAsset" do
    @asset.should be_kind_of(ActiveFedora::Base)
    @asset.should be_kind_of(FileAsset)
    @asset.should be_instance_of(AudioAsset)
  end
  
  it "should have a conforms_to relationship pointing to FileAsset" do
    @asset.ids_for_outbound(:has_model).should include("afmodel:FileAsset")
  end
  
end
