require 'chronatog/ey_integration/controllers/base'

module Chronatog
  module EyIntegration
    module Controller
      class API < Base

        #authenticate API requests
        use EY::ApiHMAC::ApiAuth::LookupServer do |env, auth_id|
          EyIntegration.api_creds && (EyIntegration.api_creds.auth_id == auth_id) && EyIntegration.api_creds.auth_key
        end

        #################
        # EY Facing API #
        #################

        post '/customers' do
          json_body = request.body.read
  #{customer_creation{
          service_account = EY::ServicesAPI::ServiceAccountCreation.from_request(json_body)
          create_params = {
            :name         => service_account.name,
            :api_url      => service_account.url,
            :messages_url => service_account.messages_url,
            :invoices_url => service_account.invoices_url
          }
          customer = Chronatog::Server::Customer.create!(create_params)
  #}customer_creation}
  #{customer_creation_response{
          response_params = {
            :configuration_required   => false,
            :configuration_url        => "#{sso_base_url}/customers/#{customer.id}",
            :provisioned_services_url => "#{api_base_url}/customers/#{customer.id}/schedulers",
            :url                      => "#{api_base_url}/customers/#{customer.id}",
            :message                  => EY::ServicesAPI::Message.new(:message_type => "status", 
                                                                      :subject      => "Thanks for signing up for Chronatog!")
          }
          response = EY::ServicesAPI::ServiceAccountResponse.new(response_params)
          content_type :json
          headers 'Location' => response.url
          response.to_hash.to_json
  #}customer_creation_response}
        end

        delete "/customers/:customer_id" do |customer_id|
          customer = Chronatog::Server::Customer.find(customer_id)
          customer.bill!
          customer.destroy
          content_type :json
          {}.to_json
        end

        post "/customers/:customer_id/schedulers" do |customer_id|
          json_body = request.body.read
          provisioned_service = EY::ServicesAPI::ProvisionedServiceCreation.from_request(json_body)

          customer = Chronatog::Server::Customer.find(customer_id)
          create_params = {
            :environment_name => provisioned_service.environment.name,
            :app_name => provisioned_service.app.name,
            :messages_url => provisioned_service.messages_url
          }
          scheduler = customer.schedulers.create!(create_params)

          response_params = {
            :configuration_required => false,
            :vars     => {
              "CHRONOS_AUTH_USERNAME" => scheduler.auth_username,
              "CHRONOS_AUTH_PASSWORD" => scheduler.auth_password,
              "CHRONOS_SERVICE_URL"   => "#{true_base_url}/chronatogapi/1/jobs",
            },
            :url      => "#{api_base_url}/customers/#{customer.id}/schedulers/#{scheduler.id}",
            :message  => EY::ServicesAPI::Message.new(:message_type => "status", 
                                                      :subject      => "Your scheduler has been created and is ready for use!")
          }
          response = EY::ServicesAPI::ProvisionedServiceResponse.new(response_params)
          content_type :json
          headers 'Location' => response.url
          response.to_hash.to_json
        end

        delete "/customers/:customer_id/schedulers/:job_id" do |customer_id, job_id|
          #TODO: hmac!

          customer = Chronatog::Server::Customer.find(customer_id)
          scheduler = customer.schedulers.find(job_id)
          scheduler.decomission!
          content_type :json
          {}.to_json
        end

      end
    end
  end
end