import re

with open('ViewModels/BackupViewModel.swift', 'r') as f:
    content = f.read()

# Add CollisionType enum and property
enum_code = """enum CollisionType {
    case normal
    case perfectlyIdentical
}

@MainActor"""
content = re.sub(r"@MainActor", enum_code, content, count=1)

prop_code = """    var showCollisionDialog: Bool = false
    var collisionMessage: String = ""
    var collisionType: CollisionType = .normal
    var collisionResolutionContinuation: CheckedContinuation<CollisionResolution, Never>?"""
content = re.sub(r"    var showCollisionDialog: Bool = false\s*var collisionMessage: String = \"\"\s*var collisionResolutionContinuation: CheckedContinuation<CollisionResolution, Never>\?", prop_code, content)

# Modify handleCollision
handle_pattern = r"""        if sourceSize == destSize \{
            message \+= "Les tailles sont identiques\. Les dossiers semblent similaires\."
        \} else if expectedMissingBytes > 0 && abs\(adjustedSourceSize - destSize\) < 20_000_000 \{ // Tolérance de 20 Mo pour les métadonnées de dossiers
            let sMissing = formatter\.string\(fromByteCount: expectedMissingBytes\)
            message \+= "La différence de taille correspond exactement \(\\\(sMissing\)\) aux dossiers que vous avez choisi d'exclure de l'archive ! Les projets principaux sont donc identiques\."
        \} else if sourceSize > destSize \{
            message \+= "La source est plus volumineuse\. Il manque probablement des éléments sur la destination\."
        \} else \{
            message \+= "La destination est plus volumineuse\."
        \}
        
        return await withCheckedContinuation \{ continuation in
            Task \{ @MainActor in
                self\.collisionMessage = message
                self\.collisionResolutionContinuation = continuation
                self\.showCollisionDialog = true
            \}
        \}"""

handle_repl = """        var type: CollisionType = .normal
        
        if sourceSize == destSize {
            message += "✅ Les tailles sont identiques. Les dossiers semblent similaires."
            type = .perfectlyIdentical
        } else if expectedMissingBytes > 0 && abs(adjustedSourceSize - destSize) < 20_000_000 {
            let sMissing = formatter.string(fromByteCount: expectedMissingBytes)
            message += "✅ La différence de taille correspond exactement (\\(sMissing)) aux dossiers que vous avez choisi d'exclure de l'archive ! L'archive est donc parfaitement à jour."
            type = .perfectlyIdentical
        } else if sourceSize > destSize {
            message += "⚠️ La source est plus volumineuse. Il manque probablement des éléments sur la destination."
        } else {
            message += "⚠️ La destination est plus volumineuse."
        }
        
        return await withCheckedContinuation { continuation in
            Task { @MainActor in
                self.collisionType = type
                self.collisionMessage = message
                self.collisionResolutionContinuation = continuation
                self.showCollisionDialog = true
            }
        }"""

content = re.sub(handle_pattern, handle_repl, content)

with open('ViewModels/BackupViewModel.swift', 'w') as f:
    f.write(content)

