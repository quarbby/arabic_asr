import sys
from difflib import SequenceMatcher
import numpy as np
import itertools

arguments = sys.argv[1::]
model_transcript_file = arguments[0]
original_transcript_file = arguments[1]


def format_transcripts(filename):
	file = open(filename, "r")
	transcripts = []
	cursor = file.readlines()
	
	for x in cursor:
		transcripts.append(x)
		
	for index in range(transcripts.__len__()):
			temp = transcripts[index]
			temp = temp.strip("\n")
			temp = temp.split(".wav", 1)
			if temp.__len__() > 1:
				temp = temp[1].split(" ", 1)
			else:
				temp = temp[0].split(" ", 1)
			temp = temp[1].strip('"')
			transcripts.pop(index)
			transcripts.insert(index, temp)
		
	return transcripts


model_transcripts = format_transcripts(model_transcript_file)
original_transcripts = format_transcripts(original_transcript_file)

accuracies = []
combined_accuracy = 0

for i in range(original_transcripts.__len__()):
	accuracy = 100
	
	if i > model_transcripts.__len__():
		accuracy = 0
	else:
		original_transcript = original_transcripts[i]
		model_transcript = model_transcripts[i]
		
		temp_list = [original_transcript, model_transcript]
		similarity = lambda x: np.mean([SequenceMatcher(None, a, b).ratio() for a, b in itertools.combinations(x, 2)])
		
		accuracy = similarity(temp_list)
		print('Accuracy of WAV file ' + str(i + 1) + ': ' + str(accuracy))
			
	accuracies.append(accuracy)
			
for accuracy in accuracies:
	combined_accuracy = combined_accuracy + accuracy
	
total_accuracy = combined_accuracy/accuracies.__len__()
print("Total Accuracy of model: " + str(total_accuracy))


