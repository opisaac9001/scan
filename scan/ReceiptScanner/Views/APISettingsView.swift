import SwiftUI

struct APISettingsView: View {
    @AppStorage("api_base_url") private var apiBaseURL = "http://localhost:11434"
    @AppStorage("api_model") private var apiModel = "llama3.2-vision:latest"
    @AppStorage("api_key") private var apiKey = ""
    @AppStorage("api_timeout") private var apiTimeout = 60.0
    @AppStorage("api_temperature") private var apiTemperature = 0.7
    @AppStorage("api_type") private var apiType = APIType.ollama.rawValue
    @AppStorage("enable_llm_processing") private var enableLLMProcessing = true
    
    @State private var isTestingConnection = false
    @State private var connectionTestResult: ConnectionTestResult?
    @State private var showingAdvancedSettings = false
    @State private var customHeaders = ""
    
    enum APIType: String, CaseIterable {
        case ollama = "ollama"
        case openai = "openai"
        case custom = "custom"
        
        var displayName: String {
            switch self {
            case .ollama: return "Ollama (Local)"
            case .openai: return "OpenAI Compatible"
            case .custom: return "Custom API"
            }
        }
        
        var defaultURL: String {
            switch self {
            case .ollama: return "http://localhost:11434"
            case .openai: return "https://api.openai.com/v1"
            case .custom: return ""
            }
        }
        
        var defaultModel: String {
            switch self {
            case .ollama: return "llama3.2-vision:latest"
            case .openai: return "gpt-4-vision-preview"
            case .custom: return ""
            }
        }
        
        var requiresAPIKey: Bool {
            switch self {
            case .ollama: return false
            case .openai, .custom: return true
            }
        }
    }
    
    struct ConnectionTestResult {
        let success: Bool
        let message: String
        let responseTime: TimeInterval?
    }
    
    var currentAPIType: APIType {
        APIType(rawValue: apiType) ?? .ollama
    }
    
    var body: some View {
        NavigationView {
            Form {
                // AI Processing Toggle
                Section {
                    Toggle("Enable AI Processing", isOn: $enableLLMProcessing)
                        .onChange(of: enableLLMProcessing) { _ in
                            validateAndSave()
                        }
                } header: {
                    Text("AI Enhancement")
                } footer: {
                    Text("Use AI to automatically categorize receipts and extract detailed information. OCR will still work without AI.")
                }
                
                if enableLLMProcessing {
                    // API Type Selection
                    Section {
                        Picker("API Type", selection: $apiType) {
                            ForEach(APIType.allCases, id: \.rawValue) { type in
                                HStack {
                                    Image(systemName: iconForAPIType(type))
                                        .foregroundColor(colorForAPIType(type))
                                    Text(type.displayName)
                                }
                                .tag(type.rawValue)
                            }
                        }
                        .onChange(of: apiType) { newType in
                            updateDefaultsForAPIType(APIType(rawValue: newType) ?? .ollama)
                        }
                    } header: {
                        Text("API Configuration")
                    } footer: {
                        Text(footerTextForAPIType(currentAPIType))
                    }
                    
                    // API Settings
                    Section {
                        // Base URL
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Base URL")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            TextField("Enter API base URL", text: $apiBaseURL)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .keyboardType(.URL)
                                .textContentType(.URL)
                                .autocapitalization(.none)
                                .onChange(of: apiBaseURL) { _ in
                                    connectionTestResult = nil
                                }
                        }
                        
                        // API Key (if required)
                        if currentAPIType.requiresAPIKey {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("API Key")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                SecureField("Enter your API key", text: $apiKey)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .onChange(of: apiKey) { _ in
                                        connectionTestResult = nil
                                    }
                            }
                        }
                        
                        // Model Name
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Model Name")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            TextField("Enter model name", text: $apiModel)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .onChange(of: apiModel) { _ in
                                    connectionTestResult = nil
                                }
                        }
                        
                        // Connection Test Button
                        Button(action: testConnection) {
                            HStack {
                                if isTestingConnection {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "network")
                                }
                                Text(isTestingConnection ? "Testing..." : "Test Connection")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .disabled(isTestingConnection || apiBaseURL.isEmpty || (currentAPIType.requiresAPIKey && apiKey.isEmpty))
                        .buttonStyle(.borderedProminent)
                        
                        // Connection Test Result
                        if let result = connectionTestResult {
                            HStack {
                                Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundColor(result.success ? .green : .red)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(result.message)
                                        .font(.caption)
                                        .foregroundColor(result.success ? .green : .red)
                                    
                                    if let responseTime = result.responseTime {
                                        Text("Response time: \(String(format: "%.2f", responseTime))s")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                Spacer()
                            }
                            .padding(.vertical, 4)
                        }
                        
                    } header: {
                        Text("Connection Settings")
                    }
                    
                    // Advanced Settings
                    Section {
                        DisclosureGroup("Advanced Settings", isExpanded: $showingAdvancedSettings) {
                            VStack(spacing: 16) {
                                // Temperature Setting
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text("Temperature")
                                        Spacer()
                                        Text(String(format: "%.1f", apiTemperature))
                                            .foregroundColor(.secondary)
                                    }
                                    Slider(value: $apiTemperature, in: 0...2, step: 0.1)
                                    Text("Controls randomness in AI responses. Lower values are more focused and deterministic.")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                // Timeout Setting
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text("Request Timeout")
                                        Spacer()
                                        Text("\(Int(apiTimeout))s")
                                            .foregroundColor(.secondary)
                                    }
                                    Slider(value: $apiTimeout, in: 10...120, step: 10)
                                    Text("Maximum time to wait for API responses before timing out.")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                // Custom Headers (for advanced users)
                                if currentAPIType == .custom {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Custom Headers (JSON)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        TextEditor(text: $customHeaders)
                                            .frame(height: 80)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .stroke(Color.gray.opacity(0.3))
                                            )
                                        Text("Optional custom headers as JSON object. Example: {\"Custom-Header\": \"value\"}")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                    } header: {
                        Text("Performance Settings")
                    }
                    
                    // Popular API Presets
                    Section {
                        VStack(spacing: 12) {
                            APIPresetButton(
                                title: "Local Ollama",
                                subtitle: "Run AI models locally",
                                icon: "desktopcomputer",
                                color: .blue
                            ) {
                                setPreset(.ollama, url: "http://localhost:11434", model: "llama3.2-vision:latest")
                            }
                            
                            APIPresetButton(
                                title: "OpenAI",
                                subtitle: "Official OpenAI API",
                                icon: "brain.head.profile",
                                color: .green
                            ) {
                                setPreset(.openai, url: "https://api.openai.com/v1", model: "gpt-4-vision-preview")
                            }
                            
                            APIPresetButton(
                                title: "LM Studio",
                                subtitle: "Local LM Studio server",
                                icon: "laptopcomputer",
                                color: .purple
                            ) {
                                setPreset(.custom, url: "http://localhost:1234/v1", model: "llava-v1.5-7b-q4")
                            }
                            
                            APIPresetButton(
                                title: "Groq",
                                subtitle: "Ultra-fast inference",
                                icon: "bolt.fill",
                                color: .orange
                            ) {
                                setPreset(.openai, url: "https://api.groq.com/openai/v1", model: "llava-v1.5-7b-4096-preview")
                            }
                        }
                    } header: {
                        Text("Quick Setup Presets")
                    } footer: {
                        Text("Choose a preset to quickly configure popular API services. You can customize the settings afterward.")
                    }
                }
            }
            .navigationTitle("AI Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        validateAndSave()
                    }
                    .disabled(!isConfigurationValid)
                }
            }
        }
    }
    
    private var isConfigurationValid: Bool {
        if !enableLLMProcessing { return true }
        
        let hasValidURL = !apiBaseURL.isEmpty && URL(string: apiBaseURL) != nil
        let hasValidAPIKey = !currentAPIType.requiresAPIKey || !apiKey.isEmpty
        let hasValidModel = !apiModel.isEmpty
        
        return hasValidURL && hasValidAPIKey && hasValidModel
    }
    
    private func iconForAPIType(_ type: APIType) -> String {
        switch type {
        case .ollama: return "desktopcomputer"
        case .openai: return "brain.head.profile"
        case .custom: return "gearshape.2"
        }
    }
    
    private func colorForAPIType(_ type: APIType) -> Color {
        switch type {
        case .ollama: return .blue
        case .openai: return .green
        case .custom: return .purple
        }
    }
    
    private func footerTextForAPIType(_ type: APIType) -> String {
        switch type {
        case .ollama:
            return "Ollama runs AI models locally on your device. Install Ollama and download a vision model like llama3.2-vision."
        case .openai:
            return "Use OpenAI's official API or any OpenAI-compatible service. Requires an API key."
        case .custom:
            return "Configure any custom API endpoint that follows OpenAI-compatible format."
        }
    }
    
    private func updateDefaultsForAPIType(_ type: APIType) {
        apiBaseURL = type.defaultURL
        apiModel = type.defaultModel
        if !type.requiresAPIKey {
            apiKey = ""
        }
        connectionTestResult = nil
    }
    
    private func setPreset(_ type: APIType, url: String, model: String) {
        apiType = type.rawValue
        apiBaseURL = url
        apiModel = model
        connectionTestResult = nil
    }
    
    private func testConnection() {
        isTestingConnection = true
        
        Task {
            let startTime = Date()
            
            do {
                let service = OllamaService(baseURL: apiBaseURL, modelName: apiModel)
                // Test with a simple prompt
                let success = await service.testConnection(apiKey: currentAPIType.requiresAPIKey ? apiKey : nil)
                
                let responseTime = Date().timeIntervalSince(startTime)
                
                await MainActor.run {
                    connectionTestResult = ConnectionTestResult(
                        success: success,
                        message: success ? "Connection successful!" : "Connection failed",
                        responseTime: responseTime
                    )
                    isTestingConnection = false
                }
            } catch {
                let responseTime = Date().timeIntervalSince(startTime)
                
                await MainActor.run {
                    connectionTestResult = ConnectionTestResult(
                        success: false,
                        message: "Error: \(error.localizedDescription)",
                        responseTime: responseTime
                    )
                    isTestingConnection = false
                }
            }
        }
    }
    
    private func validateAndSave() {
        // Validation and saving logic would go here
        // For now, settings are automatically saved via @AppStorage
        print("✅ API settings saved successfully")
    }
}

struct APIPresetButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                    .frame(width: 32)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    APISettingsView()
}
