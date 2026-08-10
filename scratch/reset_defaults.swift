import Foundation

let defaults = UserDefaults.standard
defaults.removeObject(forKey: "rushFolderName")
defaults.removeObject(forKey: "renderFolderName")
defaults.synchronize()
print("Defaults reset!")
