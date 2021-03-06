require 'time'
require 'contrib/elasticsearch/test_helper'
require 'helper'

class HTTPIntegrationTest < Minitest::Test
  ELASTICSEARCH_HOST = '127.0.0.1'.freeze
  ELASTICSEARCH_PORT = 49200
  ELASTICSEARCH_SERVER = ('http://' +
                          HTTPIntegrationTest::ELASTICSEARCH_HOST + ':' +
                          HTTPIntegrationTest::ELASTICSEARCH_PORT.to_s).freeze

  def setup
    skip unless ENV['TEST_DATADOG_INTEGRATION'] # requires a running agent

    # Here we use the default tracer (to make a real integration test)
    @tracer = Datadog.tracer

    # wait until it's really running, docker-compose can be slow
    wait_http_server 'http://' + ELASTICSEARCH_HOST + ':' + ELASTICSEARCH_PORT.to_s, 60
  end

  def test_request
    sleep(1.5) # make sure there's nothing pending
    already_flushed = @tracer.writer.stats[:traces_flushed]
    content = Net::HTTP.get(URI(ELASTICSEARCH_SERVER + '/_cluster/health'))
    assert_kind_of(String, content)
    30.times do
      break if @tracer.writer.stats[:traces_flushed] >= already_flushed + 1
      sleep(0.1)
    end
    assert_equal(already_flushed + 1, @tracer.writer.stats[:traces_flushed])
  end

  def test_block_call
    sleep(1.5) # make sure there's nothing pending
    already_flushed = @tracer.writer.stats[:traces_flushed]
    Net::HTTP.start(ELASTICSEARCH_HOST, ELASTICSEARCH_PORT) do |http|
      request = Net::HTTP::Get.new ELASTICSEARCH_SERVER
      response = http.request request
      assert_kind_of(Net::HTTPResponse, response)
      request = Net::HTTP::Get.new ELASTICSEARCH_SERVER
      response = http.request request
      assert_kind_of(Net::HTTPResponse, response)
    end
    30.times do
      break if @tracer.writer.stats[:traces_flushed] >= already_flushed + 1
      sleep(0.1)
    end
    assert_equal(already_flushed + 2, @tracer.writer.stats[:traces_flushed])
  end
end
