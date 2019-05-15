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
# frozen_string_literal: true
# encoding: utf-8
require_relative '../spec_helper'
require_relative '../../services/process_create_slice_instance_request'
require 'request'
require_relative '../../services/process_request_service'

RSpec.describe ProcessCreateSliceInstanceRequest do
  let(:uuid_1) {SecureRandom.uuid}
  let(:request_params) {{
    nst_id: uuid_1,
    request_type: 'CREATE_SLICE',
    callback: 'http://example.com/user-callback'
  }}
  let(:uuid_2) {SecureRandom.uuid}
  let(:saved_request) {{
    'callback'=>'http://example.com/user-callback', 
    'created_at'=>'2018-09-25T12:56:26.754Z', 'updated_at'=>'2018-09-25T12:56:26.754Z', 
    'service_uuid'=>uuid_1,
    'id'=>uuid_2, 
    'ingresses'=>[], 'status'=>'NEW', 'egresses'=>[], 'request_type'=>'CREATE_SLICE', 
    'name'=>'NSI_Example_MYNS_1-squid-haProxy-1', 
    'customer_name'=>'', 'customer_email'=>'', 'error'=>'',
    'instance_uuid'=>'', 'blacklist'=>[], 'sla_id'=>''
  }}
  let(:instantiating_saved_request) {{
    'callback'=>'http://example.com/user-callback', 
    'created_at'=>'2018-09-25T12:56:26.754Z', 'updated_at'=>'2018-09-25T12:56:26.754Z', 
    'service_uuid'=>uuid_1,
    'id'=>uuid_2, 
    'ingresses'=>[], 'status'=>'INSTANTIATING', 'egresses'=>[], 'request_type'=>'CREATE_SLICE', 
    'name'=>'NSI_Example_MYNS_1-squid-haProxy-1', 
    'customer_name'=>'', 'customer_email'=>'', 'error'=>'',
    'instance_uuid'=>'', 'blacklist'=>[], 'sla_id'=>''
  }}
  let(:slicer_response) {{
    created_at: "2018-07-16T14:03:02.204+00:00", updated_at: "2018-07-16T14:03:02.204+00:00",
    description: "NSI_descriptor",
    flavorId: "",
    instantiateTime: "2018-07-16T14:01:31.447547",
    name: "NSI_16072019_1600",
    netServInstance_Uuid: [
      {
        servId: "4c7d854f-a0a1-451a-b31d-8447b4fd4fbc",
        servInstanceId: "e1547f09-e954-4299-bd62-138045566872",
        servName: "ns-squid-haproxy",
        workingStatus: "READY"
      }
    ],
    :"nsi-status"=>"INSTANTIATED",
    nstId: request_params[:nst_id],
    nstName: "Example_NST",
    nstVersion: "1.0",
    sapInfo: "",
    scaleTime: "",
    terminateTime: "",
    updateTime: "",
    uuid: "a75d1555-cc2c-4b96-864f-fa1ffe5c909a",
    vendor: "eu.5gTango"
  }}
  
  describe '.call saves the request' do
    let(:error_slicer_response) {{ 
      errorLog: 'error from the Slice Manager',
      :"nsi-status"=>"ERROR"
    }}
    let(:error_saved_request) {{
      'callback'=>'http://example.com/user-callback', 
      'created_at'=>'2018-09-25T12:56:26.754Z', 'updated_at'=>'2018-09-25T12:56:26.754Z', 
      'service_uuid'=>request_params[:nst_id],
      'id'=>uuid_2, 
      'ingresses'=>[], 'status'=>'ERROR', 'egresses'=>[], 'request_type'=>'CREATE_SLICE', 
      'name'=>'NSI_Example_MYNS_1-squid-haProxy-1', 
      'customer_name'=>'', 'customer_email'=>'', 'error'=>error_slicer_response[:errorLog],
      'instance_uuid'=>'', 'blacklist'=>[], 'sla_id'=>''
    }}
    let(:enriched_request_params) {{
      request_type: request_params[:request_type],
      callback: 'http://tng-gtk-sp:5000/requests/'+error_saved_request['id']+'/on-change',
      nstId: request_params[:nst_id]
    }}

    it 'and passes it to the Slice Manager' do
      allow(described_class).to receive(:valid_request?).with(request_params).and_return(true)
      allow(described_class).to receive(:enrich_params).with(request_params).and_return(request_params)
      allow(described_class).to receive(:create_slice).and_return(slicer_response)
      req = double('Request')
      allow(Request).to receive(:create).with(request_params).and_return(req)
      allow(req).to receive(:[]).with('id').and_return(saved_request['id'])
      allow(req).to receive(:[]=).with('status', slicer_response[:'nsi-status'])
      allow(req).to receive(:save).and_return(true)
      allow(req).to receive(:as_json).and_return(saved_request)
      expect(described_class.call(request_params)).to eq(saved_request)
    end
    it 'with an error' do
      req = double('Request')
      allow(described_class).to receive(:valid_request?).with(request_params).and_return(true)
      allow(described_class).to receive(:enrich_params).with(request_params).and_return(request_params)
      allow(described_class).to receive(:create_slice).and_return(error_slicer_response) #with(enriched_request_params).
      allow(Request).to receive(:create).with(request_params).and_return(req) #saved_request)
      allow(req).to receive(:[]).with('id').and_return(saved_request['id'])
      allow(req).to receive(:[]=).with('status', error_slicer_response[:'nsi-status'])
      allow(req).to receive(:[]=).with('error', error_slicer_response[:errorLog])
      allow(req).to receive(:save).and_return(true)
      allow(Request).to receive(:find).with(saved_request['id']).and_return(req)
      allow(req).to receive(:update).with(status: 'ERROR', error: error_slicer_response[:errorLog]).and_return(error_saved_request)
      allow(req).to receive(:as_json).and_return(error_saved_request)
      STDERR.puts ">>>> #{described_class}.call(#{request_params})=#{described_class.call(request_params)}"
      STDERR.puts ">>>> error_saved_request=#{error_saved_request}"
      
      expect(described_class.call(request_params)).to eq(error_saved_request)
    end
  end
  
  describe '.process_callback' do
    let(:event_data) {{
      original_request_uuid: uuid_2,
      status: 'READY'
    }}
    it 'processes the callback of the Slice Manager when the slice is ready' do
      #request = double(id: uuid_2)
      #allow(Request).to receive(:find).with(uuid_2).and_return(request)
      allow(ProcessCreateSliceInstanceRequest).to receive(:save_result).with(event_data).and_return(event_data)
      expect(described_class.process_callback(event_data)).to eq(event_data)
    end
  end
end