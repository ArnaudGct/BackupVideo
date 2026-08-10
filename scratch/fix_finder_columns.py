import re

with open('Views/ConfigurationZoneView.swift', 'r') as f:
    content = f.read()

old_block = """                    Divider()
                    
                    // Column 3
                    if useRenderSubfolder {
                        FinderColumn {
                            FinderClickableRow(
                                title: renderSubfolderName.isEmpty ? "Sous-dossier" : renderSubfolderName,
                                icon: "folder.fill",
                                isSelected: selection == .subfolder,
                                showChevron: false,
                                action: { selection = .subfolder }
                            )
                        }
                    } else {
                        FinderColumn { EmptyView() }
                    }"""

new_block = """                    Divider()
                    
                    // Column 3
                    if useRenderSubfolder && (selection == .rendus || selection == .subfolder) {
                        FinderColumn {
                            FinderClickableRow(
                                title: renderSubfolderName.isEmpty ? "Sous-dossier" : renderSubfolderName,
                                icon: "folder.fill",
                                isSelected: selection == .subfolder,
                                showChevron: false,
                                action: { selection = .subfolder }
                            )
                        }
                    } else {
                        FinderColumn { EmptyView() }
                    }"""

content = content.replace(old_block, new_block)

with open('Views/ConfigurationZoneView.swift', 'w') as f:
    f.write(content)
