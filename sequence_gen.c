#include "utils.c"
#include <stdbool.h>

#define MAX_NOTES 1000

const uint8_t note_ranges[3] = {72, 73, 74};

//4-key representation of note
typedef struct  {
    uint8_t delta_beats;
    uint8_t note; //Only 2 bits used (when flashing to ROM)
} Note;


//Find bound/lane of midi note
uint8_t eval_bound(uint8_t note)
{
    int note_bound = 0;

    while (note_bound < 3 && note_ranges[note_bound] < note)
        note_bound++;

    return note_bound;
}


int main(void)
{
    FILE *file = fopen("twinkle.mid", "rb");
    FILE *output_file = fopen("verilog_test/midi_data/twinkle.txt", "w");

    //Reserve space for meta-data elements
    fprintf(output_file, "000\n000\n");

    Note notes[MAX_NOTES];
    int num_notes = 0;
    uint8_t tempo_bpm = 0;
    uint8_t count_in = 3; //Number of beats before start (delta-offset of each lanes first element)


    //Header chunk
    char header[4];
    uint32_t header_length;
    uint16_t format;
    uint16_t num_tracks;
    uint16_t division;

    fread(header, 1, 4, file);
    header_length = read_be32(file);
    format = read_be16(file);
    num_tracks = read_be16(file);
    division = read_be16(file);

    printf("Header: %.4s\n", header);
    printf("Header length: %u\n", header_length);
    printf("Format: %u\n", format);
    printf("Tracks: %u\n", num_tracks);
    printf("Division: %u\n", division);


    for (int track_num = 0; track_num < num_tracks; track_num++) {

        //Track chunk
        char track[4];
        uint32_t track_length;
        fread(track, 1, 4, file);
        track_length = read_be32(file);

        //Read track events
        uint32_t delta;
        uint8_t temp, e_type, e_chan;

        int global_score_time = 0;
        int lane_score_times[4] = {0,0,0,0};
        bool first_beat_flag[4] = {1,1,1,1};

        while (1){
            delta = read_vlq(file);
            global_score_time += delta;
            
            //Is meta-event!?
            if ((temp = fgetc(file)) == 0xFF){

                uint8_t meta_type = fgetc(file);
                uint32_t length = read_vlq(file);

                printf("META | Type: %02X | Length: %u\n",
                        meta_type, length);

                // End of track event
                if (meta_type == 0x2F)
                {
                    break;

                // Set tempo event
                } else if (meta_type == 0x51){

                    //Microseconds per Quarter Note (Crotchet 😡)
                    uint32_t MPQN = 0;
                    for (int i=2; i >= 0; i--){
                        //Left shift for combining 3 bytes into 24bit int
                        MPQN |= fgetc(file) << (8*i);
                    }

                    //BPM is number of micro secs in minute / MPQN
                    //Only set if first tempo event encountered (no handling of tempo change)
                    tempo_bpm = (uint8_t) (tempo_bpm == 0) ? 
                                60000000.0f / MPQN : tempo_bpm;


                    printf("Tempo change: %d\n", tempo_bpm);
                
                } else if (meta_type == 0x58){
                    //Count-in is number of numerator of time-sig (only handles x/4 sigs)
                    count_in = fgetc(file);

                    printf("sig change: %u len:%u\n", count_in, length);
                    for (int i=0; i<3; i++){fgetc(file);} //Skip other data


                } else{
                    //Skip data of meta-event (irrelevant)
                    for (uint32_t i = 0; i < length; i++){fgetc(file);}
                }

                continue;

            }

            e_type = temp & 0xF0;
            e_chan = temp & 0x0F;


            //Note on event
            if (e_type == 0x90){
                uint8_t note = fgetc(file);
                fgetc(file); //Skip velocity reading

                //Find which of 4 key-bounds note is in
                uint8_t note_bound = eval_bound(note);
                
                //Assign note element (finding the delta-time of specific lane)
                notes[num_notes].delta_beats = (uint8_t) ((global_score_time - lane_score_times[note_bound]) / (float) division);

                //First elemt in each lane needs offseting
                if (first_beat_flag[note_bound]){
                    printf("Flag");
                    notes[num_notes].delta_beats += count_in;
                    first_beat_flag[note_bound] = 0;
                }

                notes[num_notes].note = note_bound;

                printf("Delta beats: %u, Note: %u\n", notes[num_notes].delta_beats,
                                                    notes[num_notes].note);

                fprintf(output_file, "%02X%01X\n", notes[num_notes].delta_beats, notes[num_notes].note);
                num_notes++;

                lane_score_times[note_bound] = global_score_time;
            }

            //Note off event
            else if (e_type == 0x80){
                uint8_t note = fgetc(file);
                fgetc(file);
                //lane_score_times[eval_bound(note)] = global_score_time;
            }


            //Don't care for other events so handle by skipping known data-size
            else if (e_type == 0xC0 || e_type == 0xD0){
                fgetc(file);
            } else if (e_type == 0xB0 || e_type == 0xE0){
                fgetc(file); fgetc(file);

            } else{
                //UNRECOGNIZED EVENT TYPE
            }
        }
    }

    //Write num-notes to file
    fseek(output_file, 0, SEEK_SET);
    fprintf(output_file, "%02X%01X\n%03X\n", num_notes, count_in, tempo_bpm);


    fclose(file);
    fclose(output_file);
    return 0;
}
