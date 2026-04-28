import csv
import random
import datetime
import importlib.util
from pathlib import Path

# Paths
PROJECT_DIR = Path(__file__).resolve().parent.parent.parent
GENERATION_DIR = PROJECT_DIR / "generation"
SCRIPT_PATH = GENERATION_DIR / "scripts" / "01_generate_synthetic_GSS.py"
PERSONAS_FILE = PROJECT_DIR / "generation" / "data" / "gss2024_personas.csv"
OUTPUT_DIR = GENERATION_DIR / "synthetic_data" / "year_2024"
OUTPUT_FILE = OUTPUT_DIR / "random_guesser.csv"

# Dynamically import the 01 script to get GSS_QUESTIONS_COMPREHENSIVE
spec = importlib.util.spec_from_file_location("generate_gss", SCRIPT_PATH)
gen_gss = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gen_gss)

GSS_QUESTIONS = gen_gss.GSS_QUESTIONS_COMPREHENSIVE

def main():
    print("Generating random guesser data...")
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    
    # Load personas
    personas = []
    with open(PERSONAS_FILE, 'r', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        for row in reader:
            personas.append(row['respondent_id'])
    
    # Take first 300 personas to match the Nemo sweep
    personas = personas[:300]
    
    with open(OUTPUT_FILE, 'w', newline='', encoding='utf-8') as f:
        writer = csv.writer(f)
        writer.writerow([
            'timestamp', 'model', 'persona_id', 'variable', 'question_short',
            'run', 'answer', 'prompt_tokens', 'completion_tokens', 'total_tokens',
            'error', 'raw_response'
        ])
        
        for p_id in personas:
            for q_id, q_data in GSS_QUESTIONS.items():
                options = q_data['options']
                
                # Pure random guess among valid option numbers
                guess = random.choice(list(options.keys()))
                
                writer.writerow([
                    datetime.datetime.now(datetime.timezone.utc).isoformat(),
                    "random_guesser",
                    p_id,
                    q_id,
                    q_data['text'][:50] + "...",
                    1,
                    guess,
                    0, 0, 0,
                    "",
                    str(guess)
                ])
                
    print(f"Random guesser data generated: {OUTPUT_FILE}")
    print(f"Total rows: {len(personas) * len(GSS_QUESTIONS)}")

if __name__ == "__main__":
    main()
