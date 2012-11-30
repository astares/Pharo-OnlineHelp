Class {
	#name : #HelpServerPanel,
	#superclass : #Object,
	#category : #'OnlineHelp-Core'
}

{ #category : #'world menu' }
HelpServerPanel class >> menuCommandOn: aBuilder [ 
	<worldMenu> 
	(aBuilder item: #'Help Server')
		parent: #Help;
		action: [self open]; 
		icon:  UITheme current smallObjectCatalogIcon
]

{ #category : #'instance creation' }
HelpServerPanel class >> open [
	"Open within a window"
	
	^self new open
]

{ #category : #actions }
HelpServerPanel >> browsePage [

	self isBrowserSupportAvailable ifFalse: [^self].
	(Smalltalk at: #NBWin32Shell) shellBrowse: 'http://localhost:', self port asString
]

{ #category : #'ui building' }
HelpServerPanel >> buildControls [
	| builder content |
	builder := UITheme builder.
	content := (builder newColumn: {
		builder newLabelFor: self getLabel: #getServerStatus getEnabled: nil.
		builder newLabelGroup: {
			'Port:'-> (builder newTextEntryFor: self getText: #port setText: #port: help: '').
			 }.
		(builder newRow: {
			(builder newButtonFor: self action: #startServer label: 'Start server' help: '')
				getEnabledSelector: #isServerStopped.
			(builder newButtonFor: self action: #stopServer label: 'Stop server' help: '')
				getEnabledSelector: #isServerStarted.
			(builder newButtonFor: self action: #browsePage label: 'Browse' help: '')
				getEnabledSelector: #isBrowserSupportAvailable.	
		})
		vResizing: #spaceFill.
	}).

	^ content 
			width: 325;
			height: 120
]

{ #category : #accessing }
HelpServerPanel >> getServerStatus [
	^ self server isRunning
			ifTrue: ['Server running on port: ', self server port asString]
			ifFalse: ['Server stopped']
]

{ #category : #testing }
HelpServerPanel >> isBrowserSupportAvailable [
	"Return true if support for external web browsing (opening an URL from the
	  Smalltalk image) is available - false otherwise"

	^Smalltalk includesKey: #NBWin32Shell 
]

{ #category : #testing }
HelpServerPanel >> isServerStarted [
	 
	^self server isRunning  
]

{ #category : #testing }
HelpServerPanel >> isServerStopped [
 
	^self isServerStarted not
]

{ #category : #'ui opening' }
HelpServerPanel >> open [
	^ (self buildControls openInWindowLabeled: 'Pharo help server')
]

{ #category : #accessing }
HelpServerPanel >> port [
	^ self server port
]

{ #category : #accessing }
HelpServerPanel >> port: aString [ 
	| validPort |
	validPort := aString isAllDigits and: [ aString size <= 4].
 
	validPort ifTrue: [ self server port: aString asInteger.
					   self startServer ] 
	    		  ifFalse: [ self changed: #port ]. 

]

{ #category : #accessing }
HelpServerPanel >> server [
	"Return the server"
	
	^HelpServer
]

{ #category : #actions }
HelpServerPanel >> startServer [

	self server start.
	self changed: #getServerStatus.
	self update 
]

{ #category : #actions }
HelpServerPanel >> stopServer [
	self server stop.
	self changed: #getServerStatus.
	self update 
]

{ #category : #updating }
HelpServerPanel >> update [
 
	self changed: #isServerStarted; changed: #isServerStopped.
	 
]
