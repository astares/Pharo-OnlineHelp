Class {
	#name : #OHWelcomeRequestHandler,
	#superclass : #OHHelpRequestHandler,
	#category : #'OnlineHelp-Core'
}

{ #category : #'request handling' }
OHWelcomeRequestHandler >> generateHelpPage [
	 ^self helpPageWithContent: [:stream |
		
		stream << '
		<div class="navbar navbar-fixed-top">
			<div class="navbar-inner">
				<div class="container">
					<a class="brand" href="#" name="top">Pharo-Project</a>
					<div class="nav-collapse collapse">
					<ul class="nav">
						<li><a href="#"><i class="icon-home"></i> Home</a></li>
						<li><a href="/api"><i class="icon-th-list"></i> API</a></li>						
					</ul>
					</div>					
				</div>						
			</div>
			<div class="container"><br/>
			
			 
           		<div class="hero-unit">
            	<h1>Welcome</h1>
            <p>Welcome to Pharo-Project Online help. This online help should give you an introduction on how to use the Pharo Smalltalk system.</p>
            <p><a href="http://www.pharo-project.org" class="btn btn-primary btn-large">Learn more »</a></p>
          </div>
          		 
			
			
			</div>
		</div>
		
		'
		
		
	]
]

{ #category : #'request handling' }
OHWelcomeRequestHandler >> handleRequest: aRequest [
	^self htmlResponse: self generateHelpPage 
]

{ #category : #defaults }
OHWelcomeRequestHandler >> prefix [
	^'welcome'
]
