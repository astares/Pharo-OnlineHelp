Class {
	#name : #OHWelcomeRequestHandler,
	#superclass : #OHHelpRequestHandlerOld,
	#category : #'OnlineHelp-Core-Engine'
}

{ #category : #'request handling' }
OHWelcomeRequestHandler >> generateHelpPage [
	 ^self helpPageWithContent: [:stream |		
		stream << self helpNavigationMenu.		
		stream << '		 
 		<br/>
		<div class="container" style="padding-top: 40px;">
			<div class="hero-unit">
            		<h1>Welcome</h1>
            		<p>Welcome to Pharo-Project. This online help should give you an introduction on how to use the Pharo open Source Smalltalk system.</p>
            		<p><a href="/tutorials" class="btn btn-primary btn-large">Learn more »</a></p>
          		</div>
		</div>']
]

{ #category : #'request handling' }
OHWelcomeRequestHandler >> handleRequest: aRequest [
	^self htmlResponse: self generateHelpPage 
]

{ #category : #defaults }
OHWelcomeRequestHandler >> prefix [
	^'welcome'
]
