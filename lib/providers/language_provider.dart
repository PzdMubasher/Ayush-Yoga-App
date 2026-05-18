import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageProvider extends ChangeNotifier {
  String _currentLanguage = 'en'; // default to English
  bool _isLanguageSet = false;

  String get currentLanguage => _currentLanguage;
  bool get isLanguageSet => _isLanguageSet;

  LanguageProvider() {
    _loadLanguagePreference();
  }

  Future<void> _loadLanguagePreference() async {
    final prefs = await SharedPreferences.getInstance();
    _currentLanguage = prefs.getString('selected_language') ?? 'en';
    _isLanguageSet = prefs.getBool('is_language_set') ?? false;
    notifyListeners();
  }

  Future<void> setLanguage(String languageCode) async {
    _currentLanguage = languageCode;
    _isLanguageSet = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_language', languageCode);
    await prefs.setBool('is_language_set', true);
    notifyListeners();
  }

  // Dictionary for direct keys
  static const Map<String, Map<String, String>> _localizedValues = {
    'en': {
      'inhale_quote': '"Inhale peace, exhale stress"',
      'start_journey': 'Start your journey to wellness',
      'choose_focus': 'Choose Your Focus',
      'yoga_trainer': 'Ayush-Yoga-App',
      'set_session_time': 'Set Session Time',
      'yoga_categories': 'Yoga Categories',
      'show_all': 'Show All',
      'all_poses': 'All Poses',
      'key_benefits': 'Key Benefits',
      'setup_session': 'Setup Your Session',
      'intensity_level': 'Intensity Level',
      'session_duration': 'Session Duration',
      'beginner': 'Beginner',
      'intermediate': 'Intermediate',
      'advanced': 'Advanced',
      'begin_yoga': 'Begin Yoga Session',
      'journey_quote': '"Yoga is the journey of the self, through the self, to the self."',
      'getting_ready': 'Getting ready...',
      'completed': 'Completed!',
      'yoga_session_completed': 'Yoga Session Completed',
      'pose_accuracy': 'Pose Accuracy',
      'total_duration': 'Total Duration',
      'close': 'Close',
      'select_language': 'Select Language / भाषा चुनें',
      'continue_btn': 'Continue',
      'english': 'English',
      'hindi': 'हिन्दी',
      'profile_settings': 'Profile & Settings',
      'yogi_name': 'User',
      'total_minutes': 'Total Yoga Minutes',
      'change_language': 'Change Language / भाषा बदलें',
    },
    'hi': {
      'inhale_quote': '"शांति ग्रहण करें, तनाव बाहर निकालें"',
      'start_journey': 'स्वस्थ जीवन की ओर यात्रा शुरू करें',
      'choose_focus': 'अपना फोकस चुनें',
      'yoga_trainer': 'आयुष-योग-ऐप',
      'set_session_time': 'सत्र का समय निर्धारित करें',
      'yoga_categories': 'योग श्रेणियां',
      'show_all': 'सभी दिखाएं',
      'all_poses': 'सभी आसन',
      'key_benefits': 'मुख्य लाभ',
      'setup_session': 'अपने सत्र की तैयारी करें',
      'intensity_level': 'तीव्रता का स्तर',
      'session_duration': 'सत्र की अवधि',
      'beginner': 'शुरुआती',
      'intermediate': 'मध्यम',
      'advanced': 'उन्नत',
      'begin_yoga': 'योग सत्र शुरू करें',
      'journey_quote': '"योग स्वयं की, स्वयं के माध्यम से, स्वयं तक की यात्रा है।"',
      'getting_ready': 'तैयार हो रहे हैं...',
      'completed': 'पूरा हुआ!',
      'yoga_session_completed': 'योग सत्र पूरा हुआ',
      'pose_accuracy': 'आसन की शुद्धता',
      'total_duration': 'कुल अवधि',
      'close': 'बंद करें',
      'select_language': 'Select Language / भाषा चुनें',
      'continue_btn': 'आगे बढ़ें',
      'english': 'English',
      'hindi': 'हिन्दी',
      'profile_settings': 'प्रोफ़ाइल और सेटिंग्स',
      'yogi_name': 'User',
      'total_minutes': 'कुल योग मिनट',
      'change_language': 'भाषा बदलें / Change Language',
    }
  };

  // Translation lookups for dynamic texts (Pose names, descriptions, categories, benefits, rules instructions)
  static const Map<String, String> _hiDynamicTranslations = {
    // --- Categories ---
    'beginner yoga': 'शुरुआती योग',
    'basic foundation poses': 'बुनियादी आसन',
    'weight loss': 'वजन घटाने',
    'burn calories fast': 'तेजी से कैलोरी बर्न करें',
    'meditation': 'ध्यान',
    'find your inner peace': 'आंतरिक शांति पाएं',
    'strength': 'शक्ति',
    'build muscle & power': 'मांसपेशियां और ताकत बनाएं',
    'morning yoga': 'सुबह का योग',
    'start your day fresh': 'दिन की शुरुआत ताजगी से करें',
    'sleep yoga': 'नींद का योग',
    'relax for deep rest': 'गहरी नींद के लिए आराम करें',
    'therapy yoga': 'चिकित्सीय योग',
    'healing & pain relief': 'उपचार और दर्द से राहत',
    'women’s yoga': 'महिला योग',
    'female health focus': 'महिला स्वास्थ्य पर ध्यान',
    'office stretch': 'ऑफिस खिंचाव',
    'relieve desk stress': 'डेस्क तनाव दूर करें',
    'breathing': 'प्राणायाम',
    'pranayama exercises': 'श्वसन क्रिया और प्राणायाम',
    'energy boost': 'ऊर्जा बूस्टर',
    'wake up your body': 'शरीर को जगाएं',
    'kids yoga': 'बच्चों का योग',
    'fun yoga for children': 'बच्चों के लिए मजेदार योग',
    'surya namaskar': 'सूर्य नमस्कार',
    'sun salutation sequence': 'सूर्य नमस्कार अनुक्रम',
    'power yoga': 'पावर योग',
    'high intensity flow': 'उच्च तीव्रता प्रवाह',

    // --- Poses ---
    'mountain pose': 'ताड़ासन (Mountain Pose)',
    'tadasana - basic standing': 'ताड़ासन - बुनियादी खड़ी मुद्रा',
    'fixes posture': 'पोस्चर ठीक करता है',
    'improves balance': 'संतुलन में सुधार करता है',
    
    'child pose': 'बालासन (Child Pose)',
    'balasana - relaxation': 'बालासन - विश्राम',
    'calms mind': 'मन शांत करता है',
    'stretches back': 'पीठ में खिंचाव लाता है',

    'cat-cow pose': 'मार्जरी आसन (Cat-Cow)',
    'spinal flexibility': 'रीढ़ की हड्डी का लचीलापन',
    'relieves back pain': 'पीठ दर्द से राहत दिलाता है',
    'stretches spine': 'रीढ़ में खिंचाव लाता है',

    'cobra pose': 'भुजंगासन (Cobra Pose)',
    'bhujangasana': 'भुजंगासन - छाती और पीठ का खिंचाव',
    'back flexibility': 'पीठ का लचीलापन',
    'opens chest': 'छाती खोलता है',

    'downward dog': 'अधोमुख श्वानासन (Downward Dog)',
    'adho mukha svanasana': 'अधोमुख श्वानासन - पूरे शरीर का खिंचाव',
    'stretches body': 'शरीर में खिंचाव लाता है',
    'improves circulation': 'रक्त प्रवाह में सुधार करता है',

    'tree pose': 'वृक्षासन (Tree Pose)',
    'vrikshasana - balance': 'वृक्षासन - संतुलन',
    'balance': 'संतुलन',
    'leg strength': 'पैरों की ताकत',

    '12-step sun salutation': '12-चरण सूर्य नमस्कार',
    'full body detox': 'पूरे शरीर का डिटॉक्स',

    'boat pose': 'नौकासन (Boat Pose)',
    'navasana - core power': 'नौकासन - कोर शक्ति',
    'strengthens abs': 'पेट की मांसपेशियों को मजबूत करता है',
    'improves digestion': 'पाचन में सुधार करता है',

    'plank pose': 'फलाकासन (Plank Pose)',
    'phalakasana': 'फलाकासन - कोर और बांहों की ताकत',
    'core strength': 'कोर शक्ति',
    'tones arms': 'बांहों को टोन करता है',

    'warrior ii': 'वीरभद्रासन II (Warrior II)',
    'virabhadrasana ii': 'वीरभद्रासन II - स्थिरता और पैर की ताकत',
    'stamina': 'सहनशक्ति',

    'warrior i': 'वीरभद्रासन I (Warrior I)',
    'virabhadrasana i': 'वीरभद्रासन I - ध्यान और शक्ति',
    'focus': 'ध्यान केंद्रित करना',
    'lower body strength': 'निचले शरीर की ताकत',

    'warrior iii': 'वीरभद्रासन III (Warrior III)',
    'virabhadrasana iii': 'वीरभद्रासन III - संतुलन और कोर',

    'extended side angle': 'उत्थित पार्श्वकोणासन',
    'utthita parsvakonasana': 'उत्थित पार्श्वकोणासन - साइड स्ट्रेच',
    'stretches legs': 'पैरों में खिंचाव लाता है',

    'triangle pose': 'त्रिकोणासन (Triangle Pose)',
    'trikonasana': 'त्रिकोणासन - कमर और पैर का खिंचाव',
    'stretches hips': 'कूल्हों में खिंचाव लाता है',

    'half moon pose': 'अर्ध चंद्रासन (Half Moon)',
    'ardha chandrasana': 'अर्ध चंद्रासन - संतुलन और ध्यान',
    'coordination': 'समन्वय',
    'core power': 'कोर शक्ति',

    'bridge pose': 'सेतुबंधासन (Bridge Pose)',
    'setu bandhasana': 'सेतुबंधासन - पीठ और थायरॉयड स्वास्थ',
    'thyroid health': 'थायरॉयड स्वास्थ्य',
    'back strength': 'पीठ की ताकत',

    'deep breathing': 'गहरी सांस (Deep Breathing)',
    'calm your system': 'प्रणाली को शांत करें',
    'reduces anxiety': 'चिंता कम करता है',
    'lowers heart rate': 'हृदय गति कम करता है',

    'lotus pose': 'पद्मासन (Lotus Pose)',
    'padmasana - classic meditation': 'पद्मासन - ध्यान मुद्रा',
    'improves focus': 'ध्यान में सुधार करता है',

    'anulom vilom': 'अनुलोम विलोम (Anulom Vilom)',
    'alternate nostril breathing': 'नाड़ी शोधन प्राणायाम',
    'stress relief': 'तनाव से राहत',
    'mental clarity': 'मानसिक स्पष्टता',

    'kapalbhati': 'कपालभाति (Kapalbhati)',
    'skull shining breath': 'कपालभाति प्राणायाम - ऊर्जावान क्रिया',
    'digestive health': 'पाचन स्वास्थ्य',
    'energizes body': 'शरीर को ऊर्जा देता है',

    'bhramari': 'भ्रामरी (Bhramari)',
    'bee breath': 'भ्रामरी प्राणायाम - शांत मन क्रिया',
    'calms nervous system': 'तंत्रिका तंत्र को शांत करता है',

    'savasana': 'शवासन (Savasana)',
    'corpse pose': 'शवासन - गहन विश्राम',
    'deep relaxation': 'गहन विश्राम',
    'reduces bp': 'रक्तचाप नियंत्रित करता है',

    'side plank': 'वसिष्ठासन (Side Plank)',
    'vasisthasana': 'वसिष्ठासन - संतुलन और ओब्लिक',
    'oblique strength': 'कमर की मांसपेशियों की ताकत',

    'dolphin pose': 'डॉल्फिन आसन (Dolphin Pose)',
    'shoulder opener': 'कंधे खोलने वाला आसन',
    'strengthens arms': 'बांहों को मजबूत करता है',
    'calms brain': 'मस्तिष्क को शांत करता है',

    'camel pose': 'उष्ट्रासन (Camel Pose)',
    'ustrasana': 'उष्ट्रासन - छाती और रीढ़ का खिंचाव',
    'opens heart': 'हृदय चक्र खोलता है',
    'improves posture': 'पोस्चर में सुधार करता है',

    'bow pose': 'धनुरासन (Bow Pose)',
    'dhanurasana': 'धनुरासन - लचीलापन और रीढ़ की ताकत',
    'stretches front body': 'सामने के शरीर में खिंचाव',
    'strong back': 'मजबूत पीठ',

    'butterfly pose': 'बद्धकोणासन (Butterfly Pose)',
    'baddha konasana': 'बद्धकोणासन - कूल्हों का खिंचाव',
    'pelvic health': 'पेल्विक स्वास्थ्य',

    'pigeon pose': 'कपोतासन (Pigeon Pose)',
    'eka pada rajakapotasana': 'कपोतासन - गहरा हिप खिंचाव',
    'deep hip stretch': 'गहरा हिप खिंचाव',
    'relieves tension': 'तनाव दूर करता है',

    'garland pose': 'मलासन (Garland Pose)',
    'malasana': 'मलासन - डीप स्क्वाट',
    'hip mobility': 'कूल्हों की गतिशीलता',
    'strengthens ankles': 'टखनों को मजबूत करता है',

    'eagle pose': 'गरुड़ासन (Eagle Pose)',
    'garudasana': 'गरुड़ासन - जोड़ स्वास्थ और संतुलन',
    'joint health': 'जोड़ों का स्वास्थ्य',

    'fish pose': 'मत्स्यासन (Fish Pose)',
    'matsyasana': 'मत्स्यासन - छाती और फेफड़े खोलना',
    'improves breathing': 'श्वसन में सुधार करता है',

    'goddess pose': 'उत्कट कोणासन (Goddess)',
    'utkata konasana': 'उत्कट कोणासन - महिला स्वास्थ्य',
    'hip strength': 'कूल्हों की ताकत',
    'female wellness': 'महिला कल्याण',

    'neck stretch': 'गर्दन का खिंचाव (Neck Stretch)',
    'relieve neck tension': 'गर्दन के तनाव से राहत',
    'fixes neck pain': 'गर्दन के दर्द को ठीक करता है',

    'shoulder rolls': 'कंधे घुमाना (Shoulder Rolls)',
    'open shoulders': 'कंधे खोलें',

    'chair twist': 'चेयर ट्विस्ट (Chair Twist)',
    'seated spinal twist': 'कुर्सी पर बैठकर रीढ़ घुमाना',

    'wrist stretch': 'कलाई का खिंचाव (Wrist Stretch)',
    'relieve typing stress': 'टाइपिंग तनाव से राहत',
    'carpal tunnel relief': 'कार्पल टनल से राहत',

    'crow pose': 'बकासन (Crow Pose)',
    'bakasana - arm balance': 'बकासन - बांहों का संतुलन',
    'arm strength': 'बांहों की ताकत',

    'chaturanga': 'चतुरंग दंडासन (Chaturanga)',
    'low plank': 'चतुरंग दंडासन - पुशअप पोजीशन',
    'full body strength': 'पूरे शरीर की ताकत',

    'frog pose': 'मंडूकासन (Frog Pose)',
    'fun leg stretch': 'पैरों का मजेदार खिंचाव',
    'hip opening': 'कूल्हे खोलना',

    'lion breath': 'सिंह गर्जना प्राणायाम',
    'face muscle relaxation': 'चेहरे की मांसपेशियों को आराम',

    // --- General / Status ---
    'perfect.': 'बहुत बढ़िया।',
    'perfect': 'बहुत बढ़िया',
    'great! hold the pose': 'बहुत बढ़िया! आसन बनाए रखें',
    'follow the guide image and perfect your form!': 'गाइड छवि का पालन करें और अपने आसन को सुधारें!',
    'follow the guide image!': 'गाइड छवि का पालन करें!',
    'workout complete. well done. namaste.': 'कसरत पूरी हुई। बहुत बढ़िया। नमस्ते।',
    'session complete! namaste.': 'सत्र पूरा हुआ! नमस्ते।',
    'namaste': 'नमस्ते',

    // --- Dynamic Pose Step Instructions ---
    'stand tall': 'सीधे खड़े हो जाएं',
    'stand with feet together, arms at sides': 'पैरों को मिलाकर खड़े हों, हाथ बगल में रखें',
    'straighten your back more': 'अपनी पीठ को और सीधा करें',
    'arms up': 'हाथ ऊपर उठाएं',
    'raise both arms overhead, palms facing': 'दोनों हाथों को ऊपर उठाएं, हथेलियां आमने-सामने',
    'raise your arms higher': 'अपने हाथों को और ऊपर उठाएं',
    'hold': 'आसन बनाए रखें',
    'hold and breathe deeply. feel rooted.': 'सांस लें और आसन बनाए रखें। स्थिरता महसूस करें।',
    'keep your spine tall': 'अपनी रीढ़ की हड्डी को सीधा रखें',
    'stand straight': 'सीधे खड़े हो जाएं',
    'stand tall on both feet first': 'पहले दोनों पैरों पर सीधे खड़े हो जाएं',
    'lift leg': 'पैर उठाएं',
    'place one foot on inner thigh of other leg': 'एक पैर को दूसरे पैर की आंतरिक जांघ पर रखें',
    'bend your knee more to place foot on thigh': 'जांघ पर पैर रखने के लिए अपने घुटने को और मोड़ें',
    'raise arms overhead, palms together': 'दोनों हाथों को ऊपर उठाएं, हथेलियां आपस में मिलाएं',
    'stretch arms up': 'हाथों को ऊपर की ओर खींचें',
    'hold the balance. breathe steadily.': 'संतुलन बनाए रखें। गहरी और शांत सांस लें।',
    'keep your back straight': 'अपनी पीठ को सीधा रखें',
    'wide stance': 'पैरों को फैलाएं',
    'step feet wide apart, 3-4 feet': 'पैरों को 3 से 4 फीट की दूरी पर फैलाएं',
    'stand tall, don\'t lean': 'सीधे खड़े रहें, झुकें नहीं',
    'bend front knee': 'आगे का घुटना मोड़ें',
    'bend your front knee to 90 degrees': 'अपने आगे के घुटने को 90 डिग्री तक मोड़ें',
    'bend your front knee more': 'अपने आगे के घुटने को और मोड़ें',
    'don\'t bend too much': 'बहुत अधिक न झुकें',
    'extend arms': 'हाथ फैलाएं',
    'stretch both arms out at shoulder height': 'दोनों बांहों को कंधों की ऊंचाई तक सीधा फैलाएं',
    'straighten your left arm': 'अपने बाएं हाथ को सीधा करें',
    'straighten your right arm': 'अपने दाएं हाथ को सीधा करें',
    'hold & gaze': 'दृष्टि केंद्रित करें',
    'look over your front hand. hold strong!': 'सामने वाले हाथ की ओर देखें। दृढ़ रहें!',
    'keep torso upright': 'शरीर को सीधा रखें',
    'lunge position': 'लंज पोजीशन',
    'step one foot forward into a lunge': 'एक पैर आगे बढ़ाकर लंज पोजीशन में आएं',
    'bend your front knee deeper': 'आगे के घुटने को और गहरा मोड़ें',
    'raise both arms overhead': 'दोनों हाथों को सिर के ऊपर उठाएं',
    'reach arms higher': 'हाथों को और ऊपर उठाएं',
    'square your hips forward. hold.': 'कमर को सामने की ओर रखें। आसन बनाए रखें।',
    'straighten your torso': 'अपने धड़ को सीधा करें',
    'get down': 'नीचे आएं',
    'place hands on floor, shoulder-width apart': 'हाथों को फर्श पर रखें, कंधों जितनी दूरी',
    'straighten your arms': 'अपने हाथों को सीधा रखें',
    'straight body': 'सीधा शरीर',
    'keep body in one straight line head to heels': 'सिर से एड़ी तक शरीर को एक सीधी रेखा में रखें',
    'lift your hips, don\'t sag': 'अपने कूल्हों को उठाएं, झुकें नहीं',
    'hold strong': 'मजबूती से रुकें',
    'engage your core! hold this position.': 'कोर को व्यस्त रखें! इस स्थिति में रुकें।',
    'don\'t drop your hips': 'अपने कूल्हों को नीचे न गिराएं',
    'keep arms locked': 'हाथों को सीधा रखें',
    'lie down': 'लेट जाएं',
    'lie face down, palms under shoulders': 'पेट के बल लेटें, हथेलियां कंधों के नीचे',
    'lower down first': 'पहले नीचे आएं',
    'lift chest': 'छाती उठाएं',
    'press hands down, lift your chest up': 'हथेलियों को नीचे दबाते हुए छाती को ऊपर उठाएं',
    'lift your chest higher': 'अपनी छाती को और ऊपर उठाएं',
    'hold & breathe': 'रुकें और सांस लें',
    'look up, shoulders back. breathe.': 'ऊपर देखें, कंधे पीछे। सांस लेते रहें।',
    'keep chest lifted': 'छाती को ऊपर उठाकर रखें',
    'kneel down': 'घुटनों पर आएं',
    'kneel on the floor, sit on your heels': 'फर्श पर घुटने टेकें, अपनी एड़ी पर बैठें',
    'bend your knees more': 'अपने घुटनों को और मोड़ें',
    'fold forward': 'आगे झुकें',
    'stretch arms forward, rest forehead on mat': 'हाथों को आगे फैलाएं, माथा फर्श पर रखें',
    'lower your body down more': 'अपने शरीर को और नीचे लाएं',
    'relax': 'विश्राम करें',
    'relax completely. breathe deeply.': 'पूरी तरह से आराम करें। गहरी सांस लें।',
    'stay low and relaxed': 'नीचे और शांत रहें',
    'sit up': 'सीधे बैठें',
    'sit with knees bent, feet flat on floor': 'घुटनों को मोड़कर बैठें, पैर फर्श पर सपाट',
    'sit up taller': 'और सीधे बैठें',
    'lift legs': 'पैर उठाएं',
    'lean back slightly, lift legs off the floor': 'थोड़ा पीछे की ओर झुकें, पैरों को फर्श से ऊपर उठाएं',
    'keep your v-shape tighter': 'अपने वी-आकार को और कसें',
    'arms forward': 'हाथ आगे फैलाएं',
    'extend arms forward, parallel to floor': 'हाथों को आगे फैलाएं, फर्श के समानांतर',
    'extend your arms straight': 'अपने हाथों को सीधा फैलाएं',
    'hold v-shape': 'वी-आकार बनाए रखें',
    'balance on your sit bones. hold!': 'बैठने की हड्डियों पर संतुलन बनाएं। रुकें!',
    'keep the v-shape': 'वी-आकार बनाए रखें',
    'sit with spine straight on the floor': 'रीढ़ की हड्डी को फर्श पर सीधा रखते हुए बैठें',
    'feet together': 'पैरों को मिलाएं',
    'bring soles of feet together, knees out': 'पैरों के तलवों को आपस में मिलाएं, घुटने बाहर',
    'open your knees wider': 'अपने घुटनों को और चौड़ा खोलें',
    'flutter': 'तितली की तरह हिलाएं',
    'gently flutter knees up and down like wings': 'घुटनों को पंखों की तरह धीरे-धीरे ऊपर-नीचे हिलाएं',
    'keep spine tall while fluttering': 'रीढ़ की हड्डी को सीधा रखते हुए घुटनों को हिलाएं',
    'hands down': 'हाथ नीचे रखें',
    'hips up': 'कूल्हे ऊपर उठाएं',
    'push hips up and back, form an inverted v': 'कूल्हों को ऊपर और पीछे धकेलें, उल्टा वी बनाएं',
    'push hips higher': 'कूल्हों को और ऊपर उठाएं',
    'press heels toward floor. hold the pose.': 'एड़ी को फर्श की तरफ दबाएं। मुद्रा में बने रहें।',
    'keep arms straight': 'हाथों को सीधा रखें',
    'straighten your legs more': 'अपने पैरों को और सीधा करें',
    'lie on your back, knees bent, feet flat': 'पीठ के बल लेटें, घुटने मुड़े हुए, पैर सपाट',
    'bend knees to 90 degrees': 'घुटनों को 90 डिग्री तक मोड़ें',
    'lift hips': 'कूल्हे उठाएं',
    'press feet down, lift your hips up high': 'पैरों को दबाते हुए कूल्हों को ऊपर उठाएं',
    'lift your hips higher': 'कूल्हों को और ऊपर उठाएं',
    'squeeze glutes, hold the bridge!': 'नितंबों को सिकोड़ें, सेतु मुद्रा में बने रहें!',
    'keep hips lifted': 'कूल्हों को ऊपर उठाकर रखें',
    'reach down': 'नीचे पहुंचें',
    'reach one hand to ankle, other arm up': 'एक हाथ से टखने को छुएं, दूसरा हाथ ऊपर उठाएं',
    'bend to the side more': 'बगल की ओर थोड़ा और झुकें',
    'look up': 'ऊपर देखें',
    'look up at your top hand. hold.': 'ऊपर उठे हुए हाथ की ओर देखें। मुद्रा में बने रहें।',
    'extend top arm straight up': 'ऊपरी हाथ को सीधा ऊपर की ओर फैलाएं',
    'get ready! starting in 3, 2, 1': 'तैयार हो जाइए! 3, 2, 1 में शुरू हो रहा है',
    'go!': 'शुरू करें!',
    'get ready!': 'तैयार हो जाएं!',

    // Comprehensive Pose Rules Feedback Translations
    'arch back more to reach heels': 'एड़ियों तक पहुंचने के लिए पीठ को और मोड़ें',
    'arch your back more': 'अपनी पीठ को और मोड़ें',
    'arms at shoulder height, elbows bent 90°': 'हाथ कंधे की ऊंचाई पर, कोहनियाँ 90° मुड़ी हुई',
    'bend elbows more': 'कोहनियों को और मोड़ें',
    'bend elbows slightly': 'कोहनियों को थोड़ा मोड़ें',
    'bend elbows to 90 degrees': 'कोहनियों को 90 डिग्री तक मोड़ें',
    'bend elbows to 90°, lower body halfway': 'कोहनियों को 90° मोड़ें, शरीर को आधा नीचे लाएं',
    'bend forward more': 'आगे की ओर और झुकें',
    'bend knees deeper': 'घुटनों को और गहराई से मोड़ें',
    'bend knees deeply over toes': 'पंजों के ऊपर घुटनों को गहराई से मोड़ें',
    'bend knees like sitting in a chair': 'कुर्सी पर बैठने की तरह घुटनों को मोड़ें',
    'bend knees more': 'घुटनों को और मोड़ें',
    'bend knees to hop': 'उछलने के लिए घुटनों को मोड़ें',
    'bend knees, reach back and grab ankles': 'घुटने मोड़ें, पीछे की ओर पहुंचें और टखनों को पकड़ें',
    'bring hand closer to nose': 'हाथ को नाक के करीब लाएँ',
    'close eyes. breathe slowly and deeply.': 'आंखें बंद करें। धीरे और गहरी सांस लें।',
    'close right nostril, breathe in left. switch.': 'दाहिनी नाक बंद करें, बाईं से सांस लें। बदलें।',
    'close your eyes. let every muscle relax.': 'अपनी आँखें बंद करें। हर मांसपेशी को आराम दें।',

    'don\'t let hips sag': 'कूल्हों को झुकने न दें',
    'drop belly, lift head and tailbone up': 'पेट नीचे करें, सिर और टेलबोन ऊपर उठाएं',
    'exhale slowly through mouth for 6 seconds': 'मुंह से 6 सेकंड तक धीरे-धीरे सांस छोड़ें',
    'exhale, fold forward touching toes': 'सांस छोड़ते हुए आगे झुकें और पैर के अंगूठे छुएं',
    'extend one arm forward, palm up': 'एक हाथ आगे फैलाएं, हथेली ऊपर',
    'flatten your back': 'अपनी पीठ को सीधा करें',
    'forceful exhales through nose, quick pumps!': 'नाक से ज़ोर से सांस छोड़ें, जल्दी-जल्दी!',
    'forearms flat on ground': 'बांहें जमीन पर सपाट रखें',
    'get on hands and knees, back flat': 'हाथों और घुटनों पर आएं, पीठ सपाट रखें',
    'hold with elbows tucked! core tight!': 'कोहनियों को सटा कर रुकें! कोर टाइट रखें!',
    'inhale deep, exhale making a humming sound': 'गहरी सांस लें, भिनभिनाने की आवाज करते हुए छोड़ें',
    'inhale deeply through your nose for 4 seconds': 'अपनी नाक से 4 सेकंड के लिए गहरी सांस लें',
    'inhale, look up with flat back': 'सांस लें, सपाट पीठ के साथ ऊपर देखें',
    'inhale, raise arms overhead and arch back': 'सांस लें, हाथ ऊपर उठाएं और पीठ को मोड़ें',
    'keep arm straight while stretching': 'स्ट्रेच करते समय हाथ सीधा रखें',
    'keep back straight while roaring': 'दहाड़ते समय पीठ सीधी रखें',
    'keep body still, only move head': 'शरीर को स्थिर रखें, केवल सिर हिलाएं',
    'keep body straight': 'शरीर को सीधा रखें',
    'keep bottom arm straight': 'नीचे वाले हाथ को सीधा रखें',
    'keep leaning forward': 'आगे की ओर झुके रहें',
    'keep sitting tall': 'सीधे बैठे रहें',
    'keep spine straight': 'रीढ़ की हड्डी सीधी रखें',
    'kneel or sit comfortably with back straight': 'पीठ सीधी करके आराम से घुटने टेकें या बैठें',
    'kneel upright': 'घुटनों के बल सीधे खड़े हों',
    'kneel with knees hip-width apart': 'घुटनों के बीच कूल्हे जितनी दूरी रखकर घुटने टेकें',
    'lean back, reach hands to your heels': 'पीछे झुकें, हाथों को अपनी एड़ियों तक ले जाएं',
    'lean forward a bit': 'थोड़ा आगे झुकें',
    'lie completely flat': 'बिल्कुल सीधे लेट जाएं',
    'lie flat first': 'पहले सीधे लेट जाएं',
    'lie flat on your back, arms at sides': 'पीठ के बल सीधे लेटें, हाथ दोनों तरफ',
    'lie on your stomach': 'अपने पेट के बल लेटें',
    'lift chest higher': 'छाती को और ऊपर उठाएं',
    'lift hips up high like downward dog on forearms': 'नीचे की ओर कुत्ते (Downward dog) की तरह कूल्हों को ऊंचा उठाएं',
    'lift your chest': 'अपनी छाती उठाएं',

    'maintain straight posture': 'सीधी मुद्रा बनाए रखें',
    'now roll shoulders backward. repeat 10x.': 'अब कंधों को पीछे की ओर घुमाएं। 10 बार दोहराएं।',
    'now tilt head to left side. hold each side.': 'अब सिर को बाईं ओर झुकाएं। हर तरफ रुकें।',
    'now twist to the left. hold each side.': 'अब बाईं ओर मुड़ें। दोनों तरफ रुकें।',
    'open chest more': 'छाती को और खोलें',
    'open mouth wide, stick tongue out, roar!': 'मुंह चौड़ा खोलें, जीभ बाहर निकालें, दहाड़ें!',
    'place forearms on floor, shoulder-width apart': 'बांहों को फर्श पर कंधों की चौड़ाई पर रखें',
    'place hands on floor between your feet': 'हाथों को पैरों के बीच फर्श पर रखें',
    'place hands on knees, palms up': 'हाथों को घुटनों पर रखें, हथेलियाँ ऊपर की ओर',
    'place hands on knees, relax shoulders': 'हाथों को घुटनों पर रखें, कंधों को आराम दें',
    'place index fingers on ear cartilage': 'तर्जनी उंगलियों को कान पर रखें',
    'place knees on back of arms, lean forward': 'घुटनों को हाथों के पीछे रखें, आगे झुकें',
    'press forearms down, push hips back. hold.': 'बांहों को नीचे दबाएं, कूल्हों को पीछे धकेलें। रुकें।',
    'pull ankles up, lift chest and thighs!': 'टखनों को ऊपर खींचें, छाती और जांघों को उठाएं!',
    'push hips forward, open your chest to sky': 'कूल्हों को आगे धकेलें, अपनी छाती को आसमान की ओर खोलें',
    'raise arms higher': 'हाथों को और ऊपर उठाएं',
    'raise arms overhead. hold the squat!': 'हाथों को सिर के ऊपर उठाएं। स्क्वाट में रुकें!',
    'raise right hand to nose for alternate breathing': 'वैकल्पिक श्वास के लिए दाहिने हाथ को नाक तक उठाएं',
    'raise top arm to sky. hold!': 'ऊपर वाले हाथ को आसमान की ओर उठाएं। रुकें!',
    'roll shoulders forward in big circles': 'कंधों को बड़े गोलों में आगे की ओर घुमाएं',
    'rotate body to one side, stack feet': 'शरीर को एक तरफ घुमाएं, पैरों को एक के ऊपर एक रखें',
    'round your back more': 'अपनी पीठ को और गोल करें',
    'round your back up like a cat, chin to chest': 'बिल्ली की तरह अपनी पीठ को ऊपर गोल करें, ठुड्डी छाती से लगाएं',
    'sit cross-legged with spine erect': 'रीढ़ सीधी करके पालथी मारकर बैठें',
    'sit cross-legged with spine straight': 'रीढ़ सीधी करके पालथी मारकर बैठें',
    'sit in lotus or cross-legged position': 'पद्मासन या पालथी मारकर बैठें',
    'sit or stand with straight spine': 'सीधी रीढ़ के साथ बैठें या खड़े हों',
    'sit tall in a chair, feet flat on floor': 'कुर्सी पर सीधे बैठें, पैर फर्श पर सपाट',
    'sit tall in a comfortable position': 'एक आरामदायक स्थिति में सीधे बैठें',
    'sit up straight': 'सीधे बैठें',
    'sit with spine straight, close your eyes': 'रीढ़ सीधी करके बैठें, अपनी आँखें बंद करें',
    'slowly lift both feet off the ground!': 'धीरे-धीरे दोनों पैरों को जमीन से ऊपर उठाएं!',
    'slowly tilt head to right, ear to shoulder': 'धीरे-धीरे सिर को दाईं ओर झुकाएं, कान से कंधे तक',
    'squat down with feet wide apart': 'पैरों को चौड़ा करके उकड़ू बैठें',
    'squat lower': 'और नीचे उकड़ू बैठें',
    'squat lower like a frog': 'मेंढक की तरह और नीचे उकड़ू बैठें',
    'squat with feet together, hands on floor': 'पैर एक साथ रखकर उकड़ू बैठें, हाथ फर्श पर',
    'stand straight first': 'पहले सीधे खड़े हो जाएं',
    'stand tall, bring palms together at chest': 'सीधे खड़े हों, हथेलियों को छाती के पास एक साथ लाएं',

    'stand up straight': 'सीधे खड़े हो जाएं',
    'stand with arms relaxed at sides': 'बांहों को किनारों पर आराम से रखकर खड़े हों',
    'stand with feet together': 'पैरों को एक साथ रखकर खड़े हों',
    'stand with feet wide apart': 'पैरों को चौड़ा करके खड़े हों',
    'stand with feet wide, toes turned out': 'पैर चौड़े करके खड़े हों, पैर की उंगलियां बाहर की ओर',
    'start in a plank position': 'प्लैंक की स्थिति में शुरू करें',
    'start in high plank position': 'हाई प्लैंक स्थिति में शुरू करें',
    'stay relaxed and flat': 'तनावमुक्त और सीधे रहें',
    'stay tall and relaxed': 'सीधे और तनावमुक्त रहें',
    'stay tall while humming': 'भिनभिनाते समय सीधे रहें',
    'stay upright': 'सीधे रहें',
    'stay upright while breathing out': 'सांस छोड़ते समय सीधे रहें',
    'stay upright while pumping': 'पंप करते समय सीधे रहें',
    'straighten your arm': 'अपने हाथ को सीधा करें',
    'straighten your back': 'अपनी पीठ को सीधा करें',
    'straighten your legs': 'अपने पैरों को सीधा करें',
    'straighten your other arm now': 'अब अपने दूसरे हाथ को सीधा करें',
    'straighten your spine': 'अपनी रीढ़ को सीधा करें',
    'switch hands and repeat. hold 15 seconds each.': 'हाथ बदलें और दोहराएं। हर एक को 15 सेकंड तक रुकें।',
    'take a deep breath in through your nose': 'अपनी नाक से एक गहरी सांस लें',
    'try little hops like a frog! have fun!': 'मेंढक की तरह छोटी छलांग लगाने की कोशिश करें! मज़े करें!',
    'twist more to the left': 'बाईं ओर और मुड़ें',
    'twist more to the right': 'दाईं ओर और मुड़ें',
    'twist torso to the right, hold chair back': 'धड़ को दाईं ओर घुमाएं, कुर्सी के पीछे पकड़ें',
    'use other hand to pull fingers back gently': 'उंगलियों को धीरे से पीछे खींचने के लिए दूसरे हाथ का उपयोग करें',
  };

  String t(String key) {
    return _localizedValues[_currentLanguage]?[key] ?? key;
  }

  // Gracefully translate dynamic texts (case-insensitive/normalized match)
  String translateDynamic(String text) {
    if (_currentLanguage == 'en') return text;
    
    final normalized = text.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    
    // Exact dynamic map lookup
    if (_hiDynamicTranslations.containsKey(normalized)) {
      return _hiDynamicTranslations[normalized]!;
    }
    
    // Sort keys by length descending to match longest phrases first
    final keys = _hiDynamicTranslations.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
      
    bool matched = false;
    String result = normalized;
    
    for (var key in keys) {
      if (result.contains(key)) {
        result = result.replaceAll(key, _hiDynamicTranslations[key]!);
        matched = true;
      }
    }
    
    if (matched) {
      return result;
    }
    
    return text;
  }
}
