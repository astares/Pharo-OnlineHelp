Class {
	#name : #OHHelpRequestHandler,
	#superclass : #OHRequestHandler,
	#category : #'OnlineHelp-Core-Web'
}

{ #category : #testing }
OHHelpRequestHandler class >> isAbstract [
	^self name == #OHHelpRequestHandler 
]

{ #category : #'request handling' }
OHHelpRequestHandler >> handleRequest: aRequest [
	
	| context |
	context := OHRequestContext forRequest: (self requestClass fromHTTPRequest: aRequest).
	self respondUsingContext: context.
	^context htmlResponse 
	
]

{ #category : #'private-content' }
OHHelpRequestHandler >> helpNavigationMenu [
	"Returns the help navigation menu"
	
 	^'<div id="navbar-help" class="navbar navbar-fixed-top">
            <div class="navbar-inner">
                <div class="container" >
                  <a class="brand" href="http://pharo-project.org"><img src="files/img/pharo.png"> Pharo-Project</a>
                  <ul class="nav" role="navigation">
				<li><a href="/"><i class="icon-home"></i> Home</a></li>
				<li><a href="/tutorials"><i class="icon-ok-circle"></i> Intro</a></li>				
				<li class="dropdown">
                      		<a id="drop1" href="#" role="button" class="dropdown-toggle" data-toggle="dropdown"><i class="icon-book"></i> Books<b class="caret"></b></a>
                      		<ul class="dropdown-menu" role="menu" aria-labelledby="drop1">
                        		<li><a tabindex="-1" href="http://pharobyexample.org/">Pharo by Example</a></li>
                        		<li><a tabindex="-1" href="http://rmod.lille.inria.fr/pbe2/">Pharo by Example 2</a></li>		
						<li class="divider"></li>
			      		<li><a tabindex="-1" href="http://book.pharo-project.org">Collaborative Active Book</a></li>                        		 						<li class="divider"></li>
			      		<li><a tabindex="-1" href="http://stephane.ducasse.free.fr/FreeBooks.html">Free Smalltalk Books</a></li>                        		 
                     		</ul>
                    	</li>		
				<li><a href="/api"><i class="icon-th-list"></i> API</a></li>					
				<li><a href="http://www.pharocasts.com/"><i class="icon-film"></i> Pharocasts</a></li>	
                    	<li class="dropdown">
                      		<a id="drop2" href="#" role="button" class="dropdown-toggle" data-toggle="dropdown"><i class="icon-globe"></i> Links <b class="caret"></b></a>
                      		<ul class="dropdown-menu" role="menu" aria-labelledby="drop2">
                        		<li><a tabindex="-1" href="http://www.pharo-project.org"><i class="icon-home"></i></i> Pharo Homepage</a></li>		
                        		<li><a tabindex="-1" href="https://twitter.com/pharoproject"><i class="icon-time"></i> Pharo News</a></li>    
                        		<li><a tabindex="-1" href="http://association.pharo.org"><i class="icon-certificate"></i> Pharo Association </a></li>    		
						<li class="divider"></li>	  
                        		<li><a tabindex="-1" href="http://planet.smalltalk.org">Planet Smalltalk</a></li> 
				  		<li><a tabindex="-1" href="http://www.world.st">World of Smalltalk</a></li> 
						<li class="divider"></li>	  
                        		<li><a tabindex="-1" href="http://smalltalkhub.com">Smalltalk Hub</a></li> 				  	      		  		
                     		</ul>
                    	</li>
			</ul>
			<ul class="nav pull-right">
                    	<li class="dropdown pull-right">
                      		<a href="#" id="drop3" role="button" class="dropdown-toggle" data-toggle="dropdown"><i class="icon-user"></i> Community<b class="caret"></b></a>
                      		<ul class="dropdown-menu" role="menu" aria-labelledby="drop3">
                        		<li><a tabindex="-1" href="http://lists.gforge.inria.fr/cgi-bin/mailman/listinfo/pharo-users"><i class="icon-envelope"></i> Pharo-users</a></li>
			      		<li><a tabindex="-1" href="http://lists.gforge.inria.fr/cgi-bin/mailman/listinfo/pharo-project"><i class="icon-envelope"></i> Pharo-project</a></li>
                        		<li class="divider"></li>
                        		<li><a tabindex="-1" href="http://www.pharo-project.org/community/how-to-contribute"><i class="icon-user"></i> Contribute</a></li>
                        		<li class="divider"></li>
						<li><a tabindex="-1" href="http://bugs.pharo-project.org"><i class="icon-tasks"></i> Issue tracker</a></li>
						<li class="divider"></li>		                      	
                        		<li><a tabindex="-1" href="http://ci.pharo-project.org"><i class="icon-signal"></i> CI Server</a></li>
	                  		<li><a tabindex="-1" href="http://pharo.gforge.inria.fr/ci/"><i class="icon-download"></i> CI Downloads</a></li>				
                      		</ul>
                    	</li>
                  </ul>                   
                </div>
              </div>
            </div>'.
]

{ #category : #rendering }
OHHelpRequestHandler >> renderContentUsing: context [ 
	
	^self subclassResponsibility 
]

{ #category : #rendering }
OHHelpRequestHandler >> renderMenuUsing: aContext [ 
	aContext responseStream nextPutAll: self helpNavigationMenu 
]

{ #category : #accessing }
OHHelpRequestHandler >> requestClass [
	^OHHelpRequest 
]

{ #category : #'request handling' }
OHHelpRequestHandler >> respondUsingContext: aContext [
	"Respond using the given request context"
	
	|stream|
	stream := aContext responseStream.
	stream << ZnConstants standardHtmlDocType.
	stream << '<html><head><title>Pharo Help</title><link rel="shortcut icon" href="/favicon.ico"/>'.
	stream << '<link rel="stylesheet" type="text/css" href="/files/css/bootstrap.min.css">'.	
	stream <<	'
		<script src="files/js/jquery-1.8.1.min.js"></script>
		<script src="files/js/bootstrap.min.js"></script>
		<script src="files/js/MarkdownConverter.js"></script>'.			
	stream << '<style type="text/css"> '.
	stream << HelpResourceLibrary helpCss.	
	stream << '</style></head><body>'.
	self renderMenuUsing: aContext.
	self renderContentUsing: aContext.
	stream << '</body></html>' 
	
]
