Class {
	#name : #OHAPIHelpRequestTest,
	#superclass : #TestCase,
	#category : #'OnlineHelp-Tests-Core-Web'
}

{ #category : #private }
OHAPIHelpRequestTest >> requestFor: urlString [
	"Built up a simple request for the given urlString"
	
	^OHAPIHelpRequest fromHTTPRequest: (ZnRequest get: urlString asZnUrl)
]

{ #category : #tests }
OHAPIHelpRequestTest >> testAction [
	|request|
	request := (self requestFor: '/api?action=instance&item=ProtoObject').
	self 
		assert: request hasAction;
		assert: request action = 'instance'
]

{ #category : #tests }
OHAPIHelpRequestTest >> testDefaultAction [
	"If no action is given the default (comment) applies"
	
	|request|
	request := (self requestFor: '/api').
	self 
		assert: request hasAction;
		assert: request action = 'comment'
]

{ #category : #'tests-defaults' }
OHAPIHelpRequestTest >> testDefaultItem [
	"If no item is given the default (Object) applies"
	
	|request|
	request := (self requestFor: '/api').
	self 
		assert: request hasItem;
		assert: request item = 'Object'
]

{ #category : #tests }
OHAPIHelpRequestTest >> testHasAction [

	|request|
	request := (self requestFor: '/api?action=doSomething').
	self 
		assert: request hasAction;
		assert: request action = 'doSomething'
]

{ #category : #tests }
OHAPIHelpRequestTest >> testItem [
	|request|
	request := (self requestFor: '/api?action=instance&item=ProtoObject').
	self 
		assert: request hasItem;
		assert: request item = 'ProtoObject'
]

{ #category : #tests }
OHAPIHelpRequestTest >> testPrefix [

	self assert: (self requestFor: '/api?action=comment&item=ProtoObject') prefix = 'api'.	

]
