// Health Check
async function checkHealth() {
    try {
        const response = await fetch('/health');
        const data = await response.json();
        
        const statusDot = document.getElementById('status-dot');
        const statusText = document.getElementById('status-text');
        const healthDetails = document.getElementById('health-details');
        
        if (data.status === 'healthy' && data.model_loaded) {
            statusDot.className = 'status-dot healthy';
            statusText.textContent = '✅ API Healthy - Model Loaded';
            healthDetails.innerHTML = `
                <p><strong>Status:</strong> ${data.status}</p>
                <p><strong>Model:</strong> ${data.model_loaded ? 'Loaded ✓' : 'Not Loaded ✗'}</p>
            `;
        } else if (data.status === 'healthy') {
            statusDot.className = 'status-dot';
            statusText.textContent = '⚠️ API Healthy - Model Not Loaded';
            healthDetails.innerHTML = `
                <p><strong>Status:</strong> ${data.status}</p>
                <p><strong>Model:</strong> Not Loaded ✗</p>
            `;
        } else {
            statusDot.className = 'status-dot error';
            statusText.textContent = '❌ API Unhealthy';
            healthDetails.innerHTML = `<p><strong>Status:</strong> ${data.status}</p>`;
        }
    } catch (error) {
        const statusDot = document.getElementById('status-dot');
        const statusText = document.getElementById('status-text');
        statusDot.className = 'status-dot error';
        statusText.textContent = '❌ Unable to Connect';
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
    submitBtn.innerHTML = '<span class="spinner"></span> Predicting...';
    
    // Hide previous results/errors
    document.getElementById('results-section').style.display = 'none';
    document.getElementById('error-section').style.display = 'none';
    
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
            <div class="prediction-main">
                <div style="font-size: 3rem; margin-bottom: 10px;">${data.predicted_absenteeism_hours.toFixed(2)}</div>
                <div style="font-size: 1.2rem; opacity: 0.9;">hours</div>
            </div>
            <div class="prediction-details">
                <p><strong>Model Version:</strong> ${data.model_version || 'N/A'}</p>
            </div>
        `;
        
        document.getElementById('results-section').style.display = 'block';
        
        // Scroll to results
        document.getElementById('results-section').scrollIntoView({ behavior: 'smooth', block: 'start' });
        
    } catch (error) {
        // Show error
        document.getElementById('error-message').textContent = 
            `Error: ${error.message || 'An unexpected error occurred'}`;
        document.getElementById('error-section').style.display = 'block';
        
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

