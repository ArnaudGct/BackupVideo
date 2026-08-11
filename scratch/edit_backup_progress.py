import re

with open('Models/BackupProgress.swift', 'r') as f:
    content = f.read()

content = content.replace("var isRunning: Bool = false", "var isRunning: Bool = false\n    var isPaused: Bool = false\n    var isStopped: Bool = false")

with open('Models/BackupProgress.swift', 'w') as f:
    f.write(content)
