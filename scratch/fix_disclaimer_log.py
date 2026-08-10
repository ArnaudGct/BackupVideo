import re

with open('Views/DisclaimerModalView.swift', 'r') as f:
    content = f.read()

content = content.replace('LoggerService.shared.log(message: "✅ L\'utilisateur a explicitement accepté la décharge de responsabilité.", type: .success)', 'LoggerService.shared.log("[SUCCESS] L\'utilisateur a explicitement accepté la décharge de responsabilité.")')

with open('Views/DisclaimerModalView.swift', 'w') as f:
    f.write(content)
