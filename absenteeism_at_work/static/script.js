// Health Check
async function checkHealth() {
    try {
        const response = await fetch('/health');
        const data = await response.json();
        
        const statusDot = document.getElementById('status-dot');
        const statusText = document.getElementById('status-text');
        const healthDetails = document.getElementById('health-details');
        
        if (data.status === 'healthy' && data.model_loaded) {
            statusDot.className = 'w-3 h-3 rounded-full bg-green-500';
            statusText.textContent = 'API Healthy - Model Loaded';
            statusText.className = 'text-base font-medium text-green-700 dark:text-green-300';
            healthDetails.innerHTML = `
                <div class="mt-2 space-y-1">
                    <p class="text-sm"><span class="font-medium">Status:</span> ${data.status}</p>
                    <p class="text-sm"><span class="font-medium">Model:</span> Loaded ✓</p>
                </div>
            `;
        } else if (data.status === 'healthy') {
            statusDot.className = 'w-3 h-3 rounded-full bg-yellow-500 animate-pulse';
            statusText.textContent = 'API Healthy - Model Not Loaded';
            statusText.className = 'text-base font-medium text-yellow-700 dark:text-yellow-300';
            healthDetails.innerHTML = `
                <div class="mt-2 space-y-1">
                    <p class="text-sm"><span class="font-medium">Status:</span> ${data.status}</p>
                    <p class="text-sm"><span class="font-medium">Model:</span> Not Loaded ✗</p>
                </div>
            `;
        } else {
            statusDot.className = 'w-3 h-3 rounded-full bg-red-500';
            statusText.textContent = 'API Unhealthy';
            statusText.className = 'text-base font-medium text-red-700 dark:text-red-300';
            healthDetails.innerHTML = `<p class="text-sm mt-2"><span class="font-medium">Status:</span> ${data.status}</p>`;
        }
    } catch (error) {
        const statusDot = document.getElementById('status-dot');
        const statusText = document.getElementById('status-text');
        statusDot.className = 'w-3 h-3 rounded-full bg-red-500';
        statusText.textContent = 'Unable to Connect';
        statusText.className = 'text-base font-medium text-red-700 dark:text-red-300';
    }
}

// Fill Example Data
function fillExample() {
    document.getElementById('reason_for_absence').value = '23';
    document.getElementById('month_of_absence').value = '7';
    document.getElementById('day_of_the_week').value = '3';
    document.getElementById('seasons').value = '1';
    document.getElementById('transportation_expense').value = '289';
    document.getElementById('distance_from_residence_to_work').value = '36';
    document.getElementById('service_time').value = '13';
    document.getElementById('age').value = '33';
    document.getElementById('work_load_average_per_day').value = '240';
    document.getElementById('hit_target').value = '97';
    document.getElementById('disciplinary_failure').value = '0';
    document.getElementById('education').value = '1';
    document.getElementById('son').value = '2';
    document.getElementById('social_drinker').value = '1';
    document.getElementById('social_smoker').value = '0';
    document.getElementById('pet').value = '1';
    document.getElementById('weight').value = '90';
    document.getElementById('height').value = '172';
    document.getElementById('body_mass_index').value = '30';
}

// Make Prediction
async function makePrediction(formData) {
    const submitBtn = document.getElementById('submit-btn');
    const originalText = submitBtn.textContent;
    
    // Show loading state
    submitBtn.disabled = true;
    submitBtn.innerHTML = `
        <svg class="animate-spin -ml-1 mr-3 h-5 w-5 text-white inline" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
            <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
            <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
        </svg>
        Predicting...
    `;
    
    // Hide previous results/errors
    document.getElementById('results-section').classList.add('hidden');
    document.getElementById('error-section').classList.add('hidden');
    
    try {
        const response = await fetch('/predict', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify(formData)
        });
        
        if (!response.ok) {
            const errorData = await response.json();
            throw new Error(errorData.detail || `HTTP error! status: ${response.status}`);
        }
        
        const data = await response.json();
        
        // Show results
        const resultDiv = document.getElementById('prediction-result');
        resultDiv.innerHTML = `
            <div class="mb-4">
                <div class="text-5xl font-bold text-primary mb-2">${data.predicted_absenteeism_hours.toFixed(2)}</div>
                <div class="text-xl text-gray-600 dark:text-gray-400">hours</div>
            </div>
            <div class="text-sm text-gray-500 dark:text-gray-400">
                <p><span class="font-medium">Model Version:</span> ${data.model_version || 'N/A'}</p>
            </div>
        `;
        
        document.getElementById('results-section').classList.remove('hidden');
        
        // Scroll to results
        document.getElementById('results-section').scrollIntoView({ behavior: 'smooth', block: 'start' });
        
    } catch (error) {
        // Show error
        document.getElementById('error-message').textContent = 
            `Error: ${error.message || 'An unexpected error occurred'}`;
        document.getElementById('error-section').classList.remove('hidden');
        
        // Scroll to error
        document.getElementById('error-section').scrollIntoView({ behavior: 'smooth', block: 'start' });
    } finally {
        // Reset button
        submitBtn.disabled = false;
        submitBtn.textContent = originalText;
    }
}

// Form Submission
document.getElementById('prediction-form').addEventListener('submit', async (e) => {
    e.preventDefault();
    
    // Collect form data
    const formData = {
        reason_for_absence: parseInt(document.getElementById('reason_for_absence').value),
        month_of_absence: parseInt(document.getElementById('month_of_absence').value),
        day_of_the_week: parseInt(document.getElementById('day_of_the_week').value),
        seasons: parseInt(document.getElementById('seasons').value),
        transportation_expense: parseFloat(document.getElementById('transportation_expense').value),
        distance_from_residence_to_work: parseFloat(document.getElementById('distance_from_residence_to_work').value),
        service_time: parseFloat(document.getElementById('service_time').value),
        age: parseInt(document.getElementById('age').value),
        work_load_average_per_day: parseFloat(document.getElementById('work_load_average_per_day').value),
        hit_target: parseInt(document.getElementById('hit_target').value),
        disciplinary_failure: parseInt(document.getElementById('disciplinary_failure').value),
        education: parseInt(document.getElementById('education').value),
        son: parseInt(document.getElementById('son').value),
        social_drinker: parseInt(document.getElementById('social_drinker').value),
        social_smoker: parseInt(document.getElementById('social_smoker').value),
        pet: parseInt(document.getElementById('pet').value),
        weight: parseFloat(document.getElementById('weight').value),
        height: parseFloat(document.getElementById('height').value),
        body_mass_index: parseFloat(document.getElementById('body_mass_index').value)
    };
    
    await makePrediction(formData);
});

// Fill Example Button
document.getElementById('fill-example').addEventListener('click', fillExample);

// Check health on load and every 30 seconds
checkHealth();
setInterval(checkHealth, 30000);

// Helper function to get current host (for MLflow link)
function getMLflowUrl() {
    const host = window.location.hostname;
    const protocol = window.location.protocol;
    const port = window.location.port ? `:5000` : '';
    return `${protocol}//${host}${port.replace(window.location.port, '5000')}`;
}

// Update MLflow link dynamically
document.addEventListener('DOMContentLoaded', function() {
    const mlflowLink = document.getElementById('mlflow-link');
    if (mlflowLink) {
        mlflowLink.href = getMLflowUrl();
    }
});
