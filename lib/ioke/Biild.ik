#!/usr/bin/env ioke

; [Ioke][ioke] is a very powerful language, running on the JVM and incorporating
; ideas from languages like [Io][io], [Ruby][ruby], and [Lisp][lisp].
; In this tutorial we will be making Biild, a simple build system much like
; the Ruby make, [Rake][rake]. I'll also assume you're at least a little
; familiar with Ruby and Rake, as I'll be drawing some parallels between them
; and Ioke. Before diving in, you should probably read the [Ioke guide][guide].
;
; The tutorial will touch on many of Ioke's features: most everything is a
; message send, implicit return, destructuring macros, the condition system, 
; and a little bit of functional programming.
;
; Biild itself is pretty simple. It will support task dependencies,
; descriptions, and namespacing, but nothing else. The bare necessities.
;
; [ioke]: http://ioke.org
; [io]: http://iolanguage.com
; [ruby]: http://ruby-lang.org
; [lisp]: http://en.wikipedia.org/wiki/Lisp_(programming_language)
; [rake]: http://rake.rubyforge.org
; [guide]: http://ioke.org/wiki/index.php/Guide

; To make things easier on ourselves later, we'll start out by making a helper
; method to return the correct path separator of the platform Biild is on.
FileSystem separator = method(
	; Since control structures in Ioke are just messages, not special language
	; constructs, they can return values just like any another message.
	; The `case` method works just like `switch` in other languages, but it
	; doesn't require explicit `return` or `break` calls. The `"\\"` or `"/"`
	; is returned implicitly.
	case(System windows?,
		true, "\\",
		false, "/"))

;### The Biild Object

; The `Biild` object controls the show.
Biild = Origin mimic do(
	; The current namespace isn't stored as a string, but a list of names.
	; Each element in the list is one nesting level of namespacing.
	; That way, as namespaces are entered and exited, they are actually pushed
	; and popped to the list of namespaces which is treated as a stack.
	ns = []
	; Biild keeps an internal list of `Task` objects, each one represents a
	; single task.
	tasks = [])

;### The Task Object

; A Biild task is just a named block of Ioke code, exactly like Rake tasks.
; There is nothing new here.
; A task can have dependencies, a description, and a body.
Task = Origin mimic do(
	; When a `Task` is invoked, two things happen.
	invoke = method(
		; First, each dependency of the task is invoked if it hasn't been
		; already.
		; If any dependency fails, Biild immediately stops processing.
		@dependencies each(d,
			; A task stores its dependencies as a list of task names, but a
			; `Task` object of the dependency is needed to actually invoke it.
			; Since task names can be symbols or strings, the `asText` method
			; needs to be used for comparison, otherwise :task_name and
			; "task_name" would be treated as two different tasks.
			dep = Biild tasks select(t, t name asText == d asText) first
			; The `@success` instance variable of a `Task` object is `true` if
			; it has already been invoked successfully. What we're actually
			; checking for is the existence of a `success` cell on the
			; dependency, we don't really need the boolean because if a task
			; fails Boid stops processing anyway.
			if(dep cell?(:success) not, dep invoke)
			if(dep success not,
				error!("Dependency `#{dep name}' of `#{@name}' failed")))
		; Secondly, we take advantage of Ioke's condition system to invoke
		; tasks in a controlled environment. The condition system is sort of
		; similar to exception handling, but it would do you good to [read up
		; about them][csguide] in the Ioke guide if you haven't already.
		;
		; The `bind` macro accepts a `Restart`, `Rescue`, or `Handler` as a
		; first parameter, and any message as its second parameter. Just like
		; any Ioke message, it can return a value and we're manipulating that
		; so `@success` will always be a boolean value.
		;
		; [csguide]: http://ioke.org/wiki/index.php/Guide#Conditions
		@success = if(bind(
			; This rescue call will rescue any condition raised by the code in
			; the second parameter to `bind` because no specific conditions to
			; accept are specified.
			; The `.` is a message terminator, so first the condition's report
			; will be printed and then `false` will be returned to `bind`.
			rescue(fn(c, c report println. false)),
			; The body of the task is finally evaluated here.
			; It is sent to `Ground`, and whatever value this evaluates to is
			; what is returned to `bind`.
			@body evaluateOn(Ground)
		; Depending on what is returned to the `bind` macro, `@success` will
		; evaluate to `true` or `false`.
		) is?(false), false, true)))

;### The Biild Object, revisited
;
; Code doesn't need to be inside of a `do` block to be applied to a specific
; object, qualification can also be used. The means
;
;    Biild do(
;      addTask := method())
;
; is equivalent to:
;
;    Biild addTask := method()

; Adding a task is as simple as calling `Biild addTask` and passing a name
; and code. Names can be symbols:
;
;    addTask(:open, "fortune cookie wisdom" println)
;
; They can also be strings:
;
;    addTask("sup", "greetings from your homeboy" println)
;
; If you want to get fancy, i.e., mocking command-line arguments with tasks,
; names can also be lists which will alias the task to each name in the list.
;
;    addTask(["-v", "--verbose"], "annoying messages enabled" println)
;
; Ioke also supports arguments with default values. The `desc` parameter
; defaults to `nil`.
Biild addTask = method(name, body, desc nil,
	; Both the task name and dependencies are taken from the name parameter.
	; If `name` is of the `Pair` kind, it means something like this happened:
	;
	;     addTask(:task => :dependency, ...)
	;
	; The `=>` operator returns a `Pair` object, which is a key/value pair.
	; The `first` method of a `Pair` returns the key, and the `second`
	; method returns the value.
	;
	; Since we can check if the `name` is a pair, we can tell if any
	; dependencies are given to the task.
	deps = if(name kind?("Pair"),
		; The dependencies are always treated as a list. If the dependency
		; given is already a list it is left alone, otherwise its converted to
		; a list.
		if(name second kind?("List"), name second, [name second]),
		; If no dependencies were given in `name`, then we default to the
		; empty list `[]`.
		[])
	; The name of the task is also treated internally as a list, each element
	; of the list being an alias for the task.
	if(name kind?("Pair"), name = name first)
	names = if(name kind?("List"), name, [name])
	names each(name,
		; The fully qualified name of a task is dependent on its namespace.
		; The current namespace is stored in `Biild ns`, and the string name
		; of the task is the current namespace and task name joined by `":"`
		; just like in Rake.
		name = (ns + [name]) join(":")
		; No two tasks can have the same name in the same namespace.
		if(tasks map(name asText) include?(name asText),
			error!("Task `#{name}' already defined"))
		; Since everything has worked out so far, a new `Task` object is
		; created for the task. The `with` method is a nice Ioke feature, it
		; takes advantage of named arguments. `with` creates a new mimic of
		; the object it is called on, and each named argument is created as
		; an instance variable in the new mimic.
		; Ioke also shares `<<`, the list append operator, with Ruby.
		@tasks << Task with(name: name, dependencies: deps, body: body, desc: desc)))

; Biild only recognizes certain files as valid Biildfiles.
; The `getFiles` method accepts a search path as a string, and returns a list
; of valid Biildfiles in that directory with qualified path names.
Biild getFiles = method(search_path,
	["Biildfile", "biildfile", "Biildfile.ik", "biildfile.ik"] map(f,
		search_path + FileSystem separator + f) select(f,
			FileSystem file?(f)))

;### The Biildfile DSL

; The DSL used in Biildfiles are implemented as [destructuring macros][dmacros].
; A dmacro is different from a regular macro in that is can destructure the
; arguments it is given and respond to them accordingly.
;
; Accepted signatures in dmacros are defined by argument lists. If an argument
; is prefixed with `>` it means that it should be evaluated before being passed
; to the macro body, otherwise the argument is unevaluated and is left as a
; `Message` object.
;
; [dmacros]: http://ioke.org/wiki/index.php/Guide#Macros
namespace = dmacro(
	; The `namespace` dmacro only accepts one signature, where it receives
	; `name` and `code` parameters.
	; The `name` parameter is evaluated because no manipulations need to be
	; performed on it, but the `code` parameter is left alone.
	[>name, code]
		; A new namespace nesting level is added.
		Biild ns << name
		; Then the code is evaluated in the context of whatever called the
		; `namespace` macro, which is probably the Biildfile.
		code evaluateOn(call ground)
		; Once `code` is evaluated, it means we have exited the namespace and
		; Biild goes up a level in the nesting.
		Biild ns pop!)

; The `task` macro delegated all the work to `Biild addTask`, but has three
; different signatures to abstract it all away.
task = dmacro(
	; If only a name is given, a new task is created with `true` as the body.
	; This allows tasks like this to be created:
	;
	;     task(:all => [:make, :docs, :package])
	[>name] Biild addTask(name, true),
	; The most common scenario is that both a name and body are given to a task.
	;
	;    task(:docs,
	;      ; fork some process to generate html)
	[>name, code] Biild addTask(name, code),
	; Tasks can also be given a description.
	; If a description is given, it must be the second argument, and the body
	; of the task is the third.
	[>name, >description, code] Biild addTask(name, code, description))

;### The Interface

; The `System ifMain` evaluates the code passed to it if the currently
; executing script is the one that was called by the interpreter.
; It works the same as Python:
;
;     if __name__ == '__main__':
;         pass
;
; Or Ruby:
;
;     if __FILE__ == $0
;       pass
;     end
;
System ifMain(
	; The first Biildfile that exists in the current working directory is
	; used as the Biildfile. If one doesn't exist, a condition is rained and
	; processing stops.
	biildfiles = Biild getFiles(System currentWorkingDirectory)
	case(biildfiles empty?,
		false, source = FileSystem readFully(biildfiles first),
		true, error!("No biildfile found"))
	Message doText(source)
	; If no command-line parameters are passed, then it is assumed that the
	; task named `:default` is what is supposed to be invoked.
	tasks = if(System programArguments empty?, ["default"], System programArguments)
	; Finally, one by one, each task given on the command line is invoked.
	tasks each(taskName,
		atask = Biild tasks select(t, t name asText == taskName) first
		if(atask nil?, error!("No task `#{taskName}'"), atask invoke)
		if(atask success not, error!("Task `#{atask first name}' failed"))))

;#### Notes
;
; This annotation was generated by [my fork][myfork] of [Rocco][rocco], the
; quick-and-dirty literate programming annotation generator.
;
; [myfork]: http://github.com/jdp/rocco
; [rocco]: http://github.com/rtomayko/rocco
