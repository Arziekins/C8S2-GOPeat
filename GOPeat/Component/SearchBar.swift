//
//  SearchBar.swift
//  GOPeat
//
//  Created by jonathan calvin sutrisna on 30/03/25.
//

import SwiftUI

struct SearchBar: View {
    @Binding var searchTerm: String
    @FocusState.Binding var isTextFieldFocused: Bool
    var onCancel: () -> Void
    var onSearch: () -> Void
    var body: some View {
        HStack (spacing: 0){
            HStack(spacing: 5) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(searchTerm.isEmpty ? .gray : .blue)
                
                TextField("What would you eat today?", text: $searchTerm)
                    .onSubmit {
                        onSearch()
                    }
                    .focused($isTextFieldFocused)
                    .textFieldStyle(.plain)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
            }
            .padding(10)
            .background(Color(.systemGray5))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .padding(.trailing, 10)
            .animation(.smooth(duration: 0.4), value: isTextFieldFocused)
            
            if isTextFieldFocused{
                Button(action: {
                    searchTerm = ""
                    isTextFieldFocused = false
                    onCancel()
                }) {
                    Text("Cancel")
                        .foregroundColor(Color(.sample))
                }
            }
        }
        .padding(.top, 20)
    }
}
