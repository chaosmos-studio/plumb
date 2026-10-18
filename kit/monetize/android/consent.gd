extends Node

## With AdMob switched off, Google's consent service still says whether this phone needs consent, the answer
## Analytics waits on before it counts anything. No ads are loaded and no form is shown.

func _ready() -> void:
	var request: ConsentRequestParameters = ConsentRequestParameters.new()
	UserMessagingPlatform.consent_information.update(request, Analytics.refresh,
		func(_error: FormError) -> void: Analytics.refresh())
