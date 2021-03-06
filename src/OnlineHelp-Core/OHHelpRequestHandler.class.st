"
Request handler for Help items
"
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
                        		<li><a tabindex="-1" href="http://files.pharo.org/books/pharo-by-example/">Pharo by Example</a></li>
                        		<li><a tabindex="-1" href="http://files.pharo.org/books/deep-into-pharo/">Deep into Pharo</a></li>		
                        		<li><a tabindex="-1" href="http://files.pharo.org/books/enterprise-pharo/">Enterprise Pharo</a></li>		
						<li class="divider"></li>
			      		<li><a tabindex="-1" href="http://book.pharo-project.org">Collaborative Active Book</a></li>                        		 						<li class="divider"></li>
			      		<li><a tabindex="-1" href="http://stephane.ducasse.free.fr/FreeBooks.html">Free Smalltalk Books</a></li>                        		 
                     		</ul>
                    	</li>		
				<li><a href="/api"><i class="icon-th-list"></i> API</a></li>					
				<li class="dropdown">
					<a id="drop2" href="#" role="button" class="dropdown-toggle" data-toggle="dropdown"><i class="icon-film"></i> Videos <b class="caret"></b></a>
					<ul class="dropdown-menu" role="menu" aria-labelledby="drop2">
						<li><a href="https://vimeo.com/tag:pharocasts">Pharocasts</a></li>	
						<li><a href="http://www.jarober.com/blog/st4u.ssp">Smalltalk 4u</a></li>	
						<li><a href="https://www.youtube.com/watch?v=zpLY7uQnPsg&list=PLxHyfVK9FXA0Cca9LA7RNNxb8RN5ghBJN">Pharo 5 Tools</a></li>	
					</ul>
                    	</li>				
                    	<li class="dropdown">
                      		<a id="drop3" href="#" role="button" class="dropdown-toggle" data-toggle="dropdown"><i class="icon-globe"></i> Links <b class="caret"></b></a>
                      		<ul class="dropdown-menu" role="menu" aria-labelledby="drop3">
                        		<li><a tabindex="-1" href="http://www.pharo.org"><i class="icon-home"></i></i> Pharo Homepage</a></li>		
                        		<li><a tabindex="-1" href="https://twitter.com/pharoproject"><i class="icon-time"></i> Pharo News</a></li>    
						<li class="divider"></li>
						<li><a tabindex="-1" href="http://consortium.pharo.org"><i class="icon-certificate"></i> Pharo Consortium </a></li>	
                        		<li><a tabindex="-1" href="http://association.pharo.org"><i class="icon-certificate"></i> Pharo Association </a></li>    		
						<li class="divider"></li>	  
                        		<li><a tabindex="-1" href="http://planet.smalltalk.org">Planet Smalltalk</a></li> 
				  		<li><a tabindex="-1" href="http://www.world.st">World of Smalltalk</a></li> 
						<li class="divider"></li>	  
                        		<li><a tabindex="-1" href="http://smalltalkhub.com">SmalltalkHub</a></li> 				  	      		  		
                     		</ul>
                    	</li>
			</ul>
			<ul class="nav pull-right">
                    	<li class="dropdown pull-right">
                      		<a href="#" id="drop4" role="button" class="dropdown-toggle" data-toggle="dropdown"><i class="icon-user"></i> Community<b class="caret"></b></a>
                      		<ul class="dropdown-menu" role="menu" aria-labelledby="drop4">
                        		<li><a tabindex="-1" href="http://lists.pharo.org/mailman/listinfo/pharo-users_lists.pharo.org"><i class="icon-envelope"></i> Pharo users</a></li>
			      		<li><a tabindex="-1" href="http://lists.pharo.org/mailman/listinfo/pharo-dev_lists.pharo.org"><i class="icon-envelope"></i> Pharo developers</a></li>
                        		<li class="divider"></li>
                        		<li><a tabindex="-1" href="http://pharo.org/contribute"><i class="icon-user"></i> Contribute</a></li>
                        		<li class="divider"></li>
						<li><a tabindex="-1" href="http://bugs.pharo.org"><i class="icon-tasks"></i> Issue tracker</a></li>
						<li class="divider"></li>		                      	
                        		<li><a tabindex="-1" href="http://ci.pharo.org"><i class="icon-signal"></i> CI Server</a></li>
	                  		<li><a tabindex="-1" href="https://ci.inria.fr/pharo-contribution/"><i class="icon-download"></i> CI Contributions</a></li>				
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
	stream << '<!DOCTYPE html>'.
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
