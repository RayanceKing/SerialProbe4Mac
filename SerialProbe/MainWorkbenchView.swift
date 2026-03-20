//
//  MainWorkbenchView.swift
//  SerialProbe
//
//  Created by rayanceking on 2026/3/20.
//

import SwiftUI

struct MainWorkbenchView: View {
    @ObservedObject var workspace: SerialWorkspace

    var body: some View {
        VStack(spacing: 0) {
            TerminalFeedView(workspace: workspace)
            Divider()
            ComposerPanel(workspace: workspace)
        }
    }
}
