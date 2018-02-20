Promise = require 'bluebird'
logger = require 'winston'
{ captureException } = require './errors'
{ resinApi, apiKey } = require './utils'

# 10s
INTERVAL = 10 * 1000

serviceId = null
exports.getId = -> serviceId

exports.register = ->
	resinApi.post
		resource: 'service_instance'
		customOptions:
			apikey: apiKey
	.then ({ id }) ->
		if !id
			throw new Error('No service ID received on response')

		logger.info('Registered as a service instance, received ID', id)
		serviceId = id
	.catch (err) ->
		captureException(err, 'Failed to register with API', tags: service_id: serviceId)
		# Retry until it works
		Promise.delay(INTERVAL).then(exports.register)

exports.scheduleHeartbeat = ->
	Promise.delay(INTERVAL)
	.then(exports.sendHeartbeat)
	# Whether it worked or not, keep sending at the same interval
	.finally(exports.scheduleHeartbeat)

# Exposed only so that it can be tested properly
exports.sendHeartbeat = ->
	resinApi.patch
		resource: 'service_instance'
		id: serviceId
		body:
			# Just indicate being online, api handles the timestamp with hooks
			is_alive: true
		customOptions:
			apikey: apiKey
	.catch (err) ->
		captureException(err, 'Failed to send a heartbeat to the API', tags: service_id: serviceId)
