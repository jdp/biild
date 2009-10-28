;; Monkeypatch for filesystem separator
FileSystem separator = method(case(System windows?, true, "\\", false, "/"))

;; Task object
Task = Origin mimic do(
	
	invoke = method(
		@dependencies each(d,
			dep = Biild tasks select(t, t name asText == d asText) first
			if(dep cell?(:success) not, dep invoke)
			if(dep success not, error!("Dependency `#{dep name}' of `#{@name}' failed"))
		)
		@success = if(bind(
			rescue(fn(c,
				c report println
				false
			)),
			@body evaluateOn(Ground)
		) is?(false), false, true)
	)
		
)

Biild = Origin mimic do(
	
	;; Current namespace path pieces
	ns = []
	
	;; Task container
	tasks = []
	
	;; Adds a task to the list
	addTask = method(name, body, desc nil,
		dependencies = if(name kind?("Pair"), if(name second kind?("List"), name second, [name second]), [])
		if(name kind?("Pair"), name = name first)
		names = if(name kind?("List"), name, [name])
		names each(name,
			name = (ns + [name]) join(":")
			if(tasks select(t, t name asText == name asText) empty? not, error!("Task `#{name}' already defined"))
			@tasks << Task with(name: name, dependencies: dependencies, body: body, desc: desc)
		)
	)
	
	;; Returns a list of valid Biild files in the search path
	getFiles = method(search_path,
		["Biildfile", "biildfile", "Biildfile.ik", "biildfile.ik"] select(file,
			FileSystem file?(search_path + FileSystem separator + file)
		)
	)
	
)

namespace = dmacro(
	;if(call arguments size != 2, error!(Condition Error Invocation NoMatch, message: call message, context: call currentContext))
	[>name, code]
		Biild ns << name
		code evaluateOn(call ground)
		Biild ns pop!
)

task = dmacro(
	[>name] Biild addTask(name, true),
	[>name, code] Biild addTask(name, code),
	[>name, >description, code] Biild addTask(name, code, description)
)

;; Add some basic tasks
task(["--tasks", "-T"], "List all tasks and their descriptions",
	tasks = Biild tasks select(name[0] != 45)
	if(tasks empty? not,
		longest = tasks map(name length) max
		tasks each(t,
			"biild #{t name}" print
			if(t desc is?(nil) not,
				(longest - t name length) times(" " print)
				desc_trunc = 80 - (longest + 14)
				if(t desc length > desc_trunc,
					" ; #{t desc[0..desc_trunc]}..." print,
					" ; #{t desc}" print
				)
			)
			"" println
		)
	,
		"No tasks defined." println
	)
)

task(["--version", "-v"], "Shows current Biild version",
	"Biild version 0.1.0" println
	true
)

task(["--help", "-h"], "Shows basic Biild help",
	"Usage: biild [options] rule1 [rule2, rule3, ...]" println
	"Execute simple build instructions with the Ioke language." println
	"" println
	"Options:" println
	"  -T, --tasks    Show all available non-system tasks" println
	"  -v, --version  Show current Biild version" println
	"  -h, --help     Show basic help summary" println
	true
)

System ifMain(
	biildfiles = Biild getFiles(System currentDirectory)
	case(biildfiles empty?,
		false, source = FileSystem readFully(System currentDirectory + FileSystem separator + biildfiles first),
		true, source = nil
	)
	if(source == nil, error!("No biildfile found"))
	Message doText(source)
	tasks = if(System programArguments empty?, [:default], System programArguments)
	tasks each(taskName,
		task = Biild tasks select(t, t name asText == taskName)
		if(task empty? not, task first invoke, error!("No task `#{taskName}'"))
		if(task first success not, error!("Task `#{task first name}' failed"))
	)
)
