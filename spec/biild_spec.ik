use("ispec")
use("Biild")

describe("Task",
	it("should have a proper kind",
		Task should have kind("Task")
		Task kind should == "Task"
	)
	it("should not yet have a success state",
		Task should not have cell?(:success)
	)
)

describe("Biild",
	it("should have a proper kind",
		Biild should have kind("Biild")
		Biild kind should == "Biild"
	)
	it("should have 6 built-in tasks",
		Biild tasks size should == 6
	)
)
