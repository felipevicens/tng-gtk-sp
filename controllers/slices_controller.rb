## Copyright (c) 2015 SONATA-NFV, 2017 5GTANGO [, ANY ADDITIONAL AFFILIATION]
## ALL RIGHTS RESERVED.
##
## Licensed under the Apache License, Version 2.0 (the "License");
## you may not use this file except in compliance with the License.
## You may obtain a copy of the License at
##
##     http://www.apache.org/licenses/LICENSE-2.0
##
## Unless required by applicable law or agreed to in writing, software
## distributed under the License is distributed on an "AS IS" BASIS,
## WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
## See the License for the specific language governing permissions and
## limitations under the License.
##
## Neither the name of the SONATA-NFV, 5GTANGO [, ANY ADDITIONAL AFFILIATION]
## nor the names of its contributors may be used to endorse or promote
## products derived from this software without specific prior written
## permission.
##
## This work has been performed in the framework of the SONATA project,
## funded by the European Commission under Grant number 671517 through
## the Horizon 2020 and 5G-PPP programmes. The authors would like to
## acknowledge the contributions of their colleagues of the SONATA
## partner consortium (www.sonata-nfv.eu).
##
## This work has been performed in the framework of the 5GTANGO project,
## funded by the European Commission under Grant number 761493 through
## the Horizon 2020 and 5G-PPP programmes. The authors would like to
## acknowledge the contributions of their colleagues of the 5GTANGO
## partner consortium (www.5gtango.eu).
# encoding: utf-8
require 'sinatra'
require 'json'
require 'securerandom'
require 'sinatra/activerecord'
require 'tng/gtk/utils/logger'
require 'tng/gtk/utils/application_controller'
require 'tng/gtk/utils/services'
require_relative '../models/infrastructure_request'
require_relative '../services/messaging_service'
require_relative '../services/fetch_vim_resources_messaging_service'
require_relative '../services/create_networks_messaging_service'

class SlicesController < Tng::Gtk::Utils::ApplicationController
  LOGGER=Tng::Gtk::Utils::Logger
  LOGGED_COMPONENT=self.name

  @@began_at = Time.now.utc
  LOGGER.info(component:LOGGED_COMPONENT, operation:'initializing', start_stop: 'START', message:"Started at #{@@began_at}")
  MQSERVER_URL = ENV.fetch('MQSERVER_URL', '')
  if MQSERVER_URL == ''
    LOGGER.error(component:LOGGED_COMPONENT, operation:'starting', message:"No MQServer URL has been defined")
    raise ArgumentError.new('No MQServer URL has been defined') 
  end
  
  before { content_type :json}
  
  # VIMs
  get '/vims/?' do
    msg='#'+__method__.to_s
    LOGGER.info(component:LOGGED_COMPONENT, operation:msg, message:"Geting VIMs resources...")
    message_service = MessagingService.build('infrastructure.management.compute.list')
    vim_request=SliceVimResourcesRequest.create
    FetchVimResourcesMessagingService.new.call vim_request
    LOGGER.debug(component:LOGGED_COMPONENT, operation:msg, message:"vim_request.vim_list=#{vim_request.vim_list} vim_request.nep_list=#{vim_request.nep_list}")
    times = 10
    result = nil
    loop do
      sleep 1
      result = SliceVimResourcesRequest.find vim_request.id
      LOGGER.debug(component:LOGGED_COMPONENT, operation:msg, message:"times=#{times} result.vim_list=#{result.vim_list} result.nep_list=#{result.nep_list}")
      times -= 1
      break if (times == 0 || result.vim_list != '[]' || result.nep_list != '[]')
    end
    LOGGER.debug(component:LOGGED_COMPONENT, operation:msg, message:"result: #{result.inspect}")
    halt 200, {}, "{\"vim_list\":#{result.vim_list}, \"nep_list\":#{result.nep_list}}"
  end
  
  # Networks
  post '/networks/?' do
    msg='#'+__method__.to_s
    LOGGER.info(component:LOGGED_COMPONENT, operation:msg, message:"Creating networks...")
    begin
      original_body = request.body.read
      body = JSON.parse(original_body)
    rescue JSON::ParserError => e
      LOGGER.error(component:LOGGED_COMPONENT, operation:msg, message:"Error parsing network creation request #{original_body}")
      hast 404, {}, {error:"Error parsing network creation request #{original_body}"}.to_json
    end
    LOGGER.debug(component:LOGGED_COMPONENT, operation:msg, message:"body=#{body}")
    message_service = MessagingService.build('infrastructure.service.network.create')
    network_creation = SliceNetworksCreationRequest.create body
    CreateNetworksMessagingService.new.call network_creation
    times = 10
    result = nil
    loop do
      sleep 1
      result = SliceNetworksCreationRequest.find network_creation.id
      LOGGER.debug(component:LOGGED_COMPONENT, operation:msg, message:"times=#{times} result.status=#{result.status} result.error=#{result.error}")
      times -= 1
      break if (times == 0 || result.status != '' || result.error != '')
    end
    LOGGER.debug(component:LOGGED_COMPONENT, operation:msg, message:"result: #{result.inspect}")
    halt 201, {}, result.as_json.to_json 
  end
  
  delete '/networks/?' do
    msg='#'+__method__.to_s
    LOGGER.debug(component:LOGGED_COMPONENT, operation:msg, message:"Deleting networks...")
  end
  
  # WAN Networks
  post '/wan-networks/?' do
    msg='#'+__method__.to_s
    LOGGER.debug(component:LOGGED_COMPONENT, operation:msg, message:"Creating WAN networks...")
  end
  
  delete '/wan-networks/?' do
    msg='#'+__method__.to_s
    LOGGER.debug(component:LOGGED_COMPONENT, operation:msg, message:"Deleting WAN networks...")
  end
  
  private
  def build_creation_message(instance_uuid, vim_list)
    message = {}
    message['instance_uuid'] = instance_uuid
    message['vim_list'] = vim_list
    message.to_yaml
  end
  
  LOGGER.info(component:LOGGED_COMPONENT, operation:'initializing', start_stop: 'STOP', message:"Ended at #{Time.now.utc}", time_elapsed:"#{Time.now.utc-began_at}")
end