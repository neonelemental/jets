# Implements:
#
#   definition
#   template_filename
#
module Jets::Resource::ChildStack
  class Shared < AppClass
    def initialize(s3_bucket, options={})
      super
      @path = options[:path]
    end

    def definition
      logical_id = shared_logical_id
      definition = {
        logical_id => {
          type: "AWS::CloudFormation::Stack",
          properties: properties
        }
      }
      definition[logical_id][:depends_on] = depends_on if depends_on
      definition
    end

    def properties
      props = {
        template_url: template_url,
      }
      depends_on.each do |dependency|
        parameter_outputs.each do |output|
          props[:parameters] ||= {}
          dependency_class = dependency.to_s.classify
          props[:parameters][output] = "!GetAtt #{dependency_class}.Outputs.#{output}"
        end
      end if depends_on
      props
    end

    # >> Custom.new.outputs
    # => [#<Jets::Stack::Output:0x0000564048f68928 @subclass="Custom", @definition=[:billing_alarm]>, #<Jets::Stack::Output:0x0000564048f63f90 @subclass="Custom", @definition=[:billing_notification]>]
    # >> Custom.new.outputs.map(&:template)
    # => [{"BillingAlarm"=>{"Value"=>"!Ref BillingAlarm"}}, {"BillingNotification"=>{"Value"=>"!Ref BillingNotification"}}]
    # >> Custom.new.outputs.map(&:template).map {|o| o.keys.first}
    # => ["BillingAlarm", "BillingNotification"]
    # >>
    def parameter_outputs
      current_shared_class.new.outputs.map(&:template).map {|o| o.keys.first}
    end

    def depends_on
      return unless current_shared_class.depends_on
      current_shared_class.depends_on.map { |x| x.to_s.singularize.camelize }
    end

    # map the path to a camelized logical_id. Example:
    #   /tmp/jets/demo/templates/demo-dev-2-shared-resources.yml to
    #   PostsController
    def shared_logical_id
      regexp = Regexp.new(".*#{Jets.config.project_namespace}-shared-") # remove the shared
      shared_name = @path.sub(regexp, '').sub('.yml', '')
      shared_name.underscore.camelize
    end

    # IE: app/resource.rb => Resource
    # Returns Resource class object in the example
    def current_shared_class
      templates_prefix = "#{Jets::Naming.template_path_prefix}-shared-"
      @path.sub(templates_prefix, '')
        .sub(/\.yml$/,'')
        .gsub('-','/')
        .classify
        .constantize # returns actual class
    end

    # Tells us if there are any resources defined in the shared class.
    #
    # Returns: Boolean
    def resources?
      current_shared_class.build?
    end

    def template_filename
      "#{Jets.config.project_namespace}-shared-#{current_shared_class.to_s.underscore}.yml"
    end
  end
end