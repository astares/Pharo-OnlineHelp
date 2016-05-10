"
Request handler for welcome page
"
Class {
	#name : #OHWelcomeRequestHandler,
	#superclass : #OHHelpRequestHandler,
	#category : #'OnlineHelp-Core-Web'
}

{ #category : #defaults }
OHWelcomeRequestHandler >> prefix [
	"Return the prefix for tutorials"
	
	^'welcome'
]

{ #category : #rendering }
OHWelcomeRequestHandler >> renderContentUsing: aContext [   
	
	aContext responseStream << self welcomeContent 
]

{ #category : #'private-content' }
OHWelcomeRequestHandler >> welcomeContent [
	"Return the content for the welcome page"

	^'<br/>
	  <div   style="padding: 40px 40px 40px 40px">
			<div class="hero-unit">
            		<h1>Welcome</h1>
            		<p>Welcome to Pharo-Project. This online help should give you an introduction on how to use the Pharo open Source Smalltalk system.</p>
		
				<img src="http://upload.wikimedia.org/wikipedia/commons/c/cf/Pharo.png" style="width: 50%; padding-left: 200px;"/>
            		<br/><p><a href="/tutorials" class="btn btn-primary btn-large">Learn more »</a></p>
          		</div>
	   </div>'
]
