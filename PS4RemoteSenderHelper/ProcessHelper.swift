//
//  CliCommandRunner
//
//  Created by Suolapeikko
//

import Foundation

/*
 Defines the command line command and it´s arguments
 */
struct CliCommand {
    let launchPath: String
    let arguments: [String]
}

/*
 Defines possible throwable errors
 */
enum CliError: Error {
    case no_TASKS
    case execute_FAILED(statusCode: Int, resultText: String)
}

class ProcessHelper {
    
    var tasks: [Process] = []
    
    // Initializes the class with necessary command(s) and their arguments
    init(commands: [CliCommand]) {
        
        for command in commands {
            let task = Process()
            task.launchPath = command.launchPath
            task.arguments = command.arguments
            task.standardOutput = Pipe()
            tasks+=[task]
        }
    }
    
    // Execute supplied command(s)
    func execute() throws -> String {
        
        var statusCode = 0
        var resultText = ""
        let taskCount = tasks.count
        
        guard taskCount > 0 else {throw CliError.no_TASKS}
        
        // Either execute one command or chain several together
        if(tasks.count==1) {
            let task = tasks[0]
            task.launch()
            let data = (task.standardOutput! as AnyObject).fileHandleForReading.readDataToEndOfFile()
            task.waitUntilExit()
            let output: String = NSString(data: data, encoding: String.Encoding.utf8.rawValue)! as String
            statusCode = Int(task.terminationStatus)
            resultText = output.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        }
        else {
            for index in 1...taskCount {
                
                let task = tasks[index-1]
                
                if(index<taskCount) {
                    tasks[index].standardInput = task.standardOutput
                    task.launch()
                    task.waitUntilExit()
                }
                else {
                    task.launch()
                    let data = (task.standardOutput! as AnyObject).fileHandleForReading.readDataToEndOfFile()
                    task.waitUntilExit()
                    let output: String = NSString(data: data, encoding: String.Encoding.utf8.rawValue)! as String
                    statusCode = Int(task.terminationStatus)
                    resultText = output.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                    guard statusCode == 0 else {throw CliError.execute_FAILED(statusCode: statusCode, resultText: resultText)}
                }
            }
        }
        
        return resultText
    }
    
    // Execute a command chain component
    func execTmp() -> Pipe {
        let task = tasks[0]
        task.launch()
        task.waitUntilExit()
        
        return task.standardOutput as! Pipe
    }
    
    // Return this task's output stream pipe to enable command chaining functionality
    func getOutputPipe()  -> Pipe {
        
        let task = tasks[0]
        
        return task.standardOutput as! Pipe
    }
    
    // Set this task's iput stream pipe to enable command chaining functionality
    func setInputPipe(_ inputPipe: Pipe) -> ProcessHelper {
        
        let task = tasks[0]
        
        task.standardInput = inputPipe
        
        return self
    }
}
