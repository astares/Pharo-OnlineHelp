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
			repository: 'http://ss3.gemstone.com/ss/PharoOnlineHelp'.     
			 
       spec package: 'OnlineHelp'.
				
	 spec
			group: 'all' with: #('OnlineHelp');		
			group: 'default' with: #('OnlineHelp' )
								   
    ]
      
        

]

{ #category : #doIts }
ConfigurationOfPharoOnlineHelp >> postloadForCore: loader package: packageSpec [
	(Smalltalk at: #HelpServerPanel) open
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

	spec for: #'common' version: '1.1'.
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
		spec blessing: #'development'.	 
		spec description: 'first release'. 
		spec author: 'Torsten Bergmann'.
		spec timestamp: '02/12/2013 22:00'.
		spec package: 'OnlineHelp' with: 'OnlineHelp-tbn.41'.
		spec postLoadDoIt: #postloadForCore:package:
	]
]
