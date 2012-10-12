#
# Author:: Adam Jacob (<adam@opscode.com>)
# Copyright:: Copyright (c) 2008 Opscode, Inc.
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require 'ostruct'

require 'spec_helper'

describe Chef::Provider::Directory do
  before(:each) do
    @new_resource = Chef::Resource::Directory.new('/tmp')
    @new_resource.owner(500)
    @new_resource.group(500)
    @new_resource.mode(0644)
    @node = Chef::Node.new
    @events = Chef::EventDispatch::Dispatcher.new
    @run_context = Chef::RunContext.new(@node, {}, @events)

    @directory = Chef::Provider::Directory.new(@new_resource, @run_context, :create)
  end

  it "should load the current resource based on the new resource" do
    File.stub!(:exist?).and_return(true)
    cstats = mock("stats")
    cstats.stub!(:uid).and_return(500)
    cstats.stub!(:gid).and_return(500)
    cstats.stub!(:mode).and_return(0755)
    File.should_receive(:stat).once.and_return(cstats)
    @directory.load_current_resource
    @directory.current_resource.path.should eql(@new_resource.path)
    @directory.current_resource.owner.should eql(500)
    @directory.current_resource.group.should eql(500)
    @directory.current_resource.mode.should == 00755
  end

  it "should create a new directory on create, setting updated to true" do
    load_mock_provider
    @new_resource.path "/tmp/foo"
    File.should_receive(:exist?).twice.and_return(false)
    Dir.should_receive(:mkdir).with(@new_resource.path).once.and_return(true)
    @directory.should_receive(:set_all_access_controls)
    @directory.run_action(:create)
    @directory.new_resource.should be_updated
  end

  it "should raise an exception if the parent directory does not exist and recursive is false" do 
    @new_resource.path "/tmp/some/dir"
    @new_resource.recursive false
    lambda { @directory.run_action(:create) }.should raise_error(Chef::Exceptions::EnclosingDirectoryDoesNotExist) 
  end

  it "should create a new directory when parent directory does not exist if recursive is true and permissions are correct" do
    load_mock_provider
    @new_resource.path "/path/to/dir"
    @new_resource.recursive true
    File.should_receive(:exist?).with(@new_resource.path).ordered.and_return(false)
    File.should_receive(:exist?).with('/path/to').ordered.and_return(false)
    File.should_receive(:exist?).with('/path').ordered.and_return(true)
    File.should_receive(:writable?).with('/path').ordered.and_return(true)
    File.should_receive(:exist?).with(@new_resource.path).ordered.and_return(false)
 
    FileUtils.should_receive(:mkdir_p).with(@new_resource.path).and_return(true) 
    @directory.should_receive(:set_all_access_controls)
    @directory.run_action(:create)
    @new_resource.should be_updated
  end
 
  # it "should raise an error when creating a directory recursively and permissions do not allow creation" do
    
  # end

  it "should raise an error when creating a directory when parent directory is a file" do
    load_mock_provider
    File.should_receive(:directory?).and_return(false)
    Dir.should_not_receive(:mkdir).with(@new_resource.path)
    lambda { @directory.run_action(:create) }.should raise_error(Chef::Exceptions::EnclosingDirectoryDoesNotExist)
    @directory.new_resource.should_not be_updated
  end
  
  it "should not create the directory if it already exists" do
    load_mock_provider
    @new_resource.path "/tmp/foo"
    File.should_receive(:exist?).twice.and_return(true)
    Dir.should_not_receive(:mkdir).with(@new_resource.path)
    @directory.should_receive(:set_all_access_controls)
    @directory.run_action(:create)
  end

  it "should delete the directory if it exists, and is writable with action_delete" do
    load_mock_provider
    File.should_receive(:directory?).and_return(true)
    File.should_receive(:writable?).once.and_return(true)
    Dir.should_receive(:delete).with(@new_resource.path).once.and_return(true)
    @directory.run_action(:delete)
  end

  it "should raise an exception if it cannot delete the directory due to bad permissions" do
    load_mock_provider
    File.stub!(:exist?).and_return(true)
    File.stub!(:writable?).and_return(false)
    lambda {  @directory.run_action(:delete) }.should raise_error(RuntimeError)
  end

  it "should take no action when deleting a target directory that does not exist" do
    @new_resource.path "/an/invalid/path"
    File.stub!(:exist?).and_return(false)
    Dir.should_not_receive(:delete).with(@new_resource.path)
    @directory.run_action(:delete)
    @directory.new_resource.should_not be_updated
  end

  it "should raise an exception when deleting a directory when target directory is a file" do
    load_mock_provider
    @new_resource.path "/an/invalid/path"
    File.stub!(:exist?).and_return(true)
    File.should_receive(:directory?).and_return(false)
    Dir.should_not_receive(:delete).with(@new_resource.path)
    lambda { @directory.run_action(:delete) }.should raise_error(RuntimeError)
    @directory.new_resource.should_not be_updated

  end


  def load_mock_provider
    File.stub!(:exist?).and_return(true)
    File.stub!(:directory?).and_return(true)
    cstats = mock("stats")
    cstats.stub!(:uid).and_return(500)
    cstats.stub!(:gid).and_return(500)
    cstats.stub!(:mode).and_return(0755)
    File.stub!(:stat).once.and_return(cstats)
  #  @directory.load_current_resource
  end
end
