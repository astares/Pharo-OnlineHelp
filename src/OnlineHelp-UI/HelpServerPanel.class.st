"
The HelpServer panel
"
Class {
	#name : #HelpServerPanel,
	#superclass : #Object,
	#classVars : [
		'HelpServerIcon'
	],
	#category : #'OnlineHelp-UI-Server'
}

{ #category : #accessing }
HelpServerPanel class >> helpServerIcon [
	HelpServerIcon	ifNil: [ HelpServerIcon := Form fromBinaryStream: (Base64MimeConverter 
									 			     mimeDecodeToBytes: self helpServerIconContents readStream) ].		
	^HelpServerIcon
]

{ #category : #accessing }
HelpServerPanel class >> helpServerIconContents [

	^ 'iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAACLUlEQVR4XoWS3WuSYRyG/Ydq
B8FGq8gcusAwd2A4GnMb6D5qupovQVHT7URWbS+xlQcz3SZ+NVlEFlF0UkdBB1G0E3lplWX2
qq9aviPae/c8jx97HckeuODled73/l3v/b6aI/rB232TK1ndaFDqGqpj20NrD0qHdbZFTbvV
5wr8SAuCUq5UUPklo0zIl3fwkyEjWyjBMB4qtg2gk0vlCiw3jHCvjDcZm1+A9co6zFwSxxwx
pa3ZUXJAJ7v9Ewi8WcD9tzxC7+5g0BsHMcOBZjSgRA6vBqew9mEJ6+9rGKejoGavnRw++fg9
bi3j2TUPciUZp0ZXJRaQJ4nGm3rY/D70Xw/j9KUwuh0x6J1J9DiiZFKckIBpKoHAvaf4zPuR
LdYD6LuJJO0M34v+mfCB2hZugwV8L1ZJQEjSdNoCkijJ6L7YCYNrjWkPeO/CE3neZC72AnbP
ItM2O2P46BjGt3w9oIsFVLGV3WXKdLI3/ATJdBkPhd94tP0Hj7/8he/BS6ZtdsUhjI0g0wjQ
Di9v58QCJKLYSwJoofTmVEZB6utuE7pHtU2TEaTOW5ERq9DaScChkwPzJ6xzr2jacfK9aaHn
ZiKYTgiMy9E0w0LKpdom9yazzYhyLUC9GoVaZzfAJTMt0D2qfZbbRIGUmmP/wWrrH9ooVDfi
ZQ+ooXtUu+dCQqGTDRMhqUM3xLcaqArdyir7aKOtXupCpcoOioQCua7RRlu91IXSSfv5n/Y/
ket92+y+iYMAAAAASUVORK5CYII='
]

{ #category : #'world menu' }
HelpServerPanel class >> menuCommandOn: aBuilder [ 
	<worldMenu> 
	
	(aBuilder item: #'Help Server')
		parent: #Help;
		action: [self open];
		icon: self helpServerIcon
		 
]

{ #category : #'instance creation' }
HelpServerPanel class >> open [
	"Open within a window"
	
	^self new open
]

{ #category : #actions }
HelpServerPanel >> browsePage [

	self isBrowserSupportAvailable ifFalse: [^self].
	(Smalltalk at: #WebBrowser) openOn: 'http://localhost:', self port asString
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

	^Smalltalk includesKey: #WebBrowser 
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
