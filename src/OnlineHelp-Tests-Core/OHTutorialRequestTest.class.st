Class {
	#name : #OHTutorialRequestTest,
	#superclass : #TestCase,
	#category : #'OnlineHelp-Tests-Core-Web'
}

{ #category : #private }
OHTutorialRequestTest >> requestFor: urlString [
	"Built up a simple request for the given urlString"
	
	^OHTutorialRequest fromHTTPRequest: (ZnRequest get: urlString asZnUrl)
]

{ #category : #tests }
OHTutorialRequestTest >> testIncompleteURLs [

	self 
		deny: (self requestFor: '/tutorials') hasTutorial;
		deny: (self requestFor: '/tutorials?tutorial') hasTutorial;
		deny: (self requestFor: '/tutorials?x') hasTutorial.

	self 
		deny: (self requestFor: '/tutorials') hasLesson;
		deny: (self requestFor: '/tutorials?tutorial=Tutorial1') hasLesson;
		deny: (self requestFor: '/tutorials?tutorial=Tutorial1&x') hasLesson;	
		deny: (self requestFor: '/tutorials?tutorial=Tutorial1&lesson') hasLesson.
		
	self 
		deny: (self requestFor: '/tutorials') hasLesson;
		deny: (self requestFor: '/tutorials?tutorial=Tutorial1&lesson="Lesson1"&page') hasPage;
		assert: (self requestFor: '/tutorials?tutorial=Tutorial1&lesson="Lesson1"') hasPage		
		
]

{ #category : #tests }
OHTutorialRequestTest >> testLesson [

	|request|
 	request := (self requestFor: '/tutorials?lesson=Lesson%201').	
	self 
		assert: request hasLesson;
		assert: request lesson = 'Lesson 1' 
]

{ #category : #tests }
OHTutorialRequestTest >> testPage [

	|request|
 	request := (self requestFor: '/tutorials?page=Page%201').	
	self 
		assert: request hasPage;
		assert: request page = 'Page 1' 
]

{ #category : #tests }
OHTutorialRequestTest >> testPrefix [

	self assert: (self requestFor: '/tutorials?page=Page%201') prefix = 'tutorials'.	

]

{ #category : #tests }
OHTutorialRequestTest >> testTutorial [

	|request|
 	request := (self requestFor: '/tutorials?tutorial=Tutorial%201').	
	self 
		assert: request hasTutorial;
		assert: request tutorial = 'Tutorial 1' 
]
