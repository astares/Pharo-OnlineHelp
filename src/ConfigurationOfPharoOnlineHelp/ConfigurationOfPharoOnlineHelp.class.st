"
Configuration of Pharo Online Help
"
Class {
	#name : #ConfigurationOfPharoOnlineHelp,
	#superclass : #Object,
	#instVars : [
		'project'
	],
	#classVars : [
		'LastVersionLoad'
	],
	#category : #ConfigurationOfPharoOnlineHelp
}

{ #category : #private }
ConfigurationOfPharoOnlineHelp class >> bootstrapPackage: aString from: aPath [ 
	| repository version |
	repository := MCHttpRepository
				location: aPath
				user: ''
				password: ''.
	repository
		versionReaderForFileNamed: aString , '.mcz'
		do: [:reader | 
			version := reader version.
			version load.
			version workingCopy repositoryGroup addRepository: repository]
]

{ #category : #catalog }
ConfigurationOfPharoOnlineHelp class >> catalogChangeLog [
	"Returns a paragraph describing the most important changes in the configuration class."
	^ ''
]

{ #category : #catalog }
ConfigurationOfPharoOnlineHelp class >> catalogContactInfo [
	"Returns a paragraph describing contact information such as email, mailing lists and website."
	^ 'You can contact the author on the Pharo developer mailinglist http://lists.pharo.org'
]

{ #category : #catalog }
ConfigurationOfPharoOnlineHelp class >> catalogDescription [
	"Returns a paragraph describing the project"
	^ 'Implementation of an online based help system.'
]

{ #category : #catalog }
ConfigurationOfPharoOnlineHelp class >> catalogKeyClassesAndExample [
	"Returns a paragraph or more describing the key classes of your project. You can use Pillar/Pier syntax to layout out the text i.e., ==Code== and - for bullet."
	^ ''
]

{ #category : #catalog }
ConfigurationOfPharoOnlineHelp class >> catalogKeywords [
	"Returns an array of symbols"
	^ #(help online web) 
]

{ #category : #private }
ConfigurationOfPharoOnlineHelp class >> ensureMetacello [
	"Bootstrap Gofer (if necessary), bootstrap ConfigurationOfMetacello (using old Gofer API), then load the latest 
	version of Metacello itself."

	Smalltalk at: #MetacelloProject ifAbsent: [
		Smalltalk at: #Gofer ifAbsent: [
			"Current version of Gofer from which to bootstrap - as of 1.0-beta.15"
			self bootstrapPackage: 'Gofer-lr.83' from: 'http://seaside.gemstone.com/ss/metacello' ].
		Smalltalk at: #Gofer ifPresent: [:goferClass | | gofer |
			gofer := goferClass new
				url: 'http://seaside.gemstone.com/ss/metacello';
				yourself.
			[ gofer addPackage: 'ConfigurationOfMetacello' ] on: Warning do: [:ex | ex resume ].
			gofer load ].
		"load 'default' group of Metacello"
		(Smalltalk at: #ConfigurationOfMetacello) perform: #load ]
]

{ #category : #'metacello tool support' }
ConfigurationOfPharoOnlineHelp class >> isMetacelloConfig [
	"Answer true and the Metacello tools will operate on you"
	
	^true
]

{ #category : #'metacello tool support' }
ConfigurationOfPharoOnlineHelp class >> lastMetacelloVersionLoad [
	"Answer the last version loaded and the list of packages loaded for that version."

	LastVersionLoad == nil ifTrue: [ LastVersionLoad := nil -> 'default' ].
	^LastVersionLoad
]

{ #category : #loading }
ConfigurationOfPharoOnlineHelp class >> load [
	"self load"

	^self project latestVersion load
]

{ #category : #'metacello tool support' }
ConfigurationOfPharoOnlineHelp class >> metacelloVersion: versionString loads: anArrayOrString [
	"Stash the last version loaded and the list of packages loaded for that version. The list
	 of packages will be used by the tools when doing 'Load Package Version'"

	LastVersionLoad := versionString -> anArrayOrString
]

{ #category : #accessing }
ConfigurationOfPharoOnlineHelp class >> project [

	^self new project
]

{ #category : #baselines }
ConfigurationOfPharoOnlineHelp >> baseline10: spec [
    <version: '1.0-baseline'>
    
    spec for: #common do: [
        spec 
			blessing: #baseline;
			description: '1.0 baseline for Pharo Online Help';
			repository: 'http://smalltalkhub.com/mc/TorstenBergmann/PharoOnlineHelp/main'.     
			 
       spec package: 'OnlineHelp'.
				
	 spec
			group: 'all' with: #('OnlineHelp');		
			group: 'default' with: #('OnlineHelp' )
								   
    ]
      
        

]

{ #category : #baselines }
ConfigurationOfPharoOnlineHelp >> baseline20: spec [
	<version: '2.0-baseline'>

	spec for: #'common' do: [
		spec blessing: #'baseline'.
		spec repository: 'http://smalltalkhub.com/mc/TorstenBergmann/PharoOnlineHelp/main/'.
		spec project: 'WebBrowser' with: [
				spec
					className: #ConfigurationOfWebBrowser;
					versionString: #'stable';
					repository: 'http://smalltalkhub.com/mc/TorstenBergmann/WebBrowser/main/' ].
		spec 
			package: #'OnlineHelp-Core';
			package: #'OnlineHelp-Tests-Core' with: [
				spec requires: #(#'OnlineHelp-Core' ). ];
			package: #'OnlineHelp-Tools' with: [
				spec requires: #(#'OnlineHelp-Core' 'WebBrowser' ). ];
			package: #'OnlineHelp-Tutorials' with: [
				spec requires: #(#'OnlineHelp-Core' ). ].
		spec 
			group: 'Core' with: #(#'OnlineHelp-Core' );
			group: 'Tests' with: #(#'OnlineHelp-Tests-Core' );
			group: 'Tools' with: #(#'OnlineHelp-Tools' );
			group: 'Tutorials' with: #(#'OnlineHelp-Tutorials' );
			group: 'all' with: #('Core' 'Tutorials' 'Tools' 'Tests' );
			group: 'default' with: #('all' ). ].

]

{ #category : #baselines }
ConfigurationOfPharoOnlineHelp >> baseline21: spec [
	<version: '2.1-baseline'>

	spec for: #'common' do: [
		spec blessing: #'baseline'.
		spec repository: 'http://smalltalkhub.com/mc/TorstenBergmann/PharoOnlineHelp/main/'.
		spec project: 'WebBrowser' with: [
				spec
					className: #ConfigurationOfWebBrowser;
					versionString: #'stable';
					repository: 'http://smalltalkhub.com/mc/TorstenBergmann/WebBrowser/main/' ].
		spec 
			package: #'OnlineHelp-Core';
			package: #'OnlineHelp-Tests-Core' with: [
				spec requires: #(#'OnlineHelp-Core' ). ];
			package: #'OnlineHelp-Tools' with: [
				spec requires: #(#'OnlineHelp-Core' 'WebBrowser' ). ];
			package: #'OnlineHelp-Tutorials' with: [
				spec requires: #(#'OnlineHelp-Core' ). ].
		spec 
			group: 'Core' with: #(#'OnlineHelp-Core' );
			group: 'Tests' with: #(#'OnlineHelp-Tests-Core' );
			group: 'Tools' with: #(#'OnlineHelp-Tools' );
			group: 'Tutorials' with: #(#'OnlineHelp-Tutorials' );
			group: 'all' with: #('Core' 'Tutorials' 'Tools' 'Tests' );
			group: 'default' with: #('all' ). ].

]

{ #category : #'symbolic versions' }
ConfigurationOfPharoOnlineHelp >> development: spec [
	<symbolicVersion: #'development'>

	spec for: #'common' version: '2.1-baseline'.

]

{ #category : #doIts }
ConfigurationOfPharoOnlineHelp >> postloadForCore: loader package: packageSpec [
	
	Workspace openContents: '"To run the help server open Help -> HelpServer from the world menu or evaluate"

    HelpServerPanel open.

"Set the port, click on Start server and point your browser to http://localhost:8080

You can also run the server using" HelpServer start
' .
	
(Smalltalk at: #HelpServerPanel) open.
]

{ #category : #accessing }
ConfigurationOfPharoOnlineHelp >> project [

	^ project ifNil: [ | constructor |
		"Bootstrap Metacello if it is not already loaded"
		self class ensureMetacello.
		"Construct Metacello project"
		constructor := (Smalltalk at: #MetacelloVersionConstructor) on: self.
		project := constructor project.
		project loadType: #linear.
		project ]
]

{ #category : #'symbolic versions' }
ConfigurationOfPharoOnlineHelp >> stable: spec [
	<symbolicVersion: #'stable'>

	spec
		for: #common version: '2.0';
		for: #'pharo4.x' version: '1.4';
		for: #'pharo3.x' version: '1.4'

]

{ #category : #versions }
ConfigurationOfPharoOnlineHelp >> version10: spec [
	<version: '1.0' imports: #('1.0-baseline')>
	
	spec for: #common do: [
		spec blessing: #'release'.	 
		spec description: 'first release'. 
		spec author: 'Torsten Bergmann'.
		spec timestamp: '11/05/2012 22:00'.
		spec package: 'OnlineHelp' with: 'OnlineHelp-TorstenBergmann.20'.
		spec postLoadDoIt: #postloadForCore:package:
	]
]

{ #category : #versions }
ConfigurationOfPharoOnlineHelp >> version11: spec [
	<version: '1.1' imports: #('1.0-baseline')>
	
	spec for: #common do: [
		spec blessing: #'release'.	 
		spec description: 'second release'. 
		spec author: 'Torsten Bergmann'.
		spec timestamp: '02/12/2013 22:00'.
		spec package: 'OnlineHelp' with: 'OnlineHelp-tbn.58'.
		spec postLoadDoIt: #postloadForCore:package:
	]
]

{ #category : #versions }
ConfigurationOfPharoOnlineHelp >> version12: spec [
	<version: '1.2' imports: #('1.0-baseline')>
	
	spec for: #common do: [
		spec blessing: #'release'.	 
		spec description: 'release for Pharo 2.0'. 
		spec author: 'Torsten Bergmann'.
		spec timestamp: '02/12/2013 22:00'.
		spec package: 'OnlineHelp' with: 'OnlineHelp-tbn.59'.
		spec postLoadDoIt: #postloadForCore:package:
	]
]

{ #category : #versions }
ConfigurationOfPharoOnlineHelp >> version13: spec [
	<version: '1.3' imports: #('1.0-baseline')>
	
	spec for: #common do: [
		spec blessing: #'release '.	 
		spec description: 'release '. 
		spec author: 'Torsten Bergmann'.
		spec timestamp: '03/25/2013 22:00'.
		spec package: 'OnlineHelp' with: 'OnlineHelp-TorstenBergmann.63'.
		spec postLoadDoIt: #postloadForCore:package:
	]
]

{ #category : #versions }
ConfigurationOfPharoOnlineHelp >> version14: spec [
	<version: '1.4' imports: #('1.0-baseline')>
	
	spec for: #common do: [
		spec blessing: #'release '.	 
		spec description: 'release '. 
		spec author: 'Torsten Bergmann'.
		spec timestamp: '03/25/2013 22:00'.
		spec package: 'OnlineHelp' with: 'OnlineHelp-TorstenBergmann.64'.
		spec postLoadDoIt: #postloadForCore:package:
	]
]

{ #category : #versions }
ConfigurationOfPharoOnlineHelp >> version20: spec [
	<version: '2.0' imports: #('2.0-baseline' )>

	spec for: #'common' do: [
		spec blessing: #'stable'.
		spec description: 'version 2.0'.
		spec author: 'TorstenBergmann'.
		spec timestamp: '5/10/2016 18:00'.
		spec project: 'WebBrowser' with: #'stable'.
		spec 
			package: #'OnlineHelp-Core' with: 'OnlineHelp-Core-TorstenBergmann.2';
			package: #'OnlineHelp-Tests-Core' with: 'OnlineHelp-Tests-Core-TorstenBergmann.1';
			package: #'OnlineHelp-Tools' with: 'OnlineHelp-Tools-TorstenBergmann.1';
			package: #'OnlineHelp-Tutorials' with: 'OnlineHelp-Tutorials-TorstenBergmann.1'. ].
		spec postLoadDoIt: #postloadForCore:package:

]
