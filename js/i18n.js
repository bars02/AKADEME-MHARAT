/* 
  Advanced i18n Translation Engine - Optimized
  - Supports dynamic UI text
  - Persists preference
  - Handles RTL/LTR switching
  - Extensible dictionary
*/

const dictionaries = {
    en: {
        appName: "Maharat Academy",
        login: "Sign In",
        register: "Create Account",
        registerSub: "Professional vocational and medical training platform",
        fullName: "Full Name",
        role: "Professional Role",
        department: "Department",
        academicEmail: "Academic Email",
        password: "Password",
        loginSub: "Access your personalized lab environment",
        createAccount: "Register",
        alreadyHaveAccount: "Already registered?",
        noAccount: "New here?",
        entryLab: "Enter Lab",
        overview: "Overview",
        departments: "Departments",
        userManagement: "User Management",
        analytics: "Analytics",
        systemOverview: "System Overview",
        totalStudents: "Total Students",
        pendingApprovals: "Pending Approvals",
        activeDepts: "Active Departments",
        examsTaken: "Exams Taken",
        recentRegistrations: "Recent Registrations",
        approvals: "Approvals",
        results: "Results",
        users: "Users",
        logout: "Sign Out",
        checkStatus: "Check Status",
        pendingApproval: "Pending Approval",
        pendingMsg: "Your account is being verified by an administrator.",
        switchLang: "العربية",
        backToDash: "Dashboard",
        learning: "Learning",
        simulator: "Simulator",
        assistant: "AI Assistant",
        certification: "Certification",
        loadSample: "Load Sample",
        calibrate: "Calibrate",
        runAnalysis: "Run Analysis",
        submitExam: "Submit Certification",
        startExam: "Start Certification",
        begin: "Begin Now",
        examNotice: "This is a timed exam. Do not refresh.",
        myLearningPath: "My Learning Path",
        availableDevices: "Available Devices",
        overallProgress: "Overall Progress",
        devicesMastered: "Devices Mastered",
        examsPending: "Pending Review",
        averageScore: "Average Score",
        manageDevices: "Devices",
        learningMaterials: "Materials",
        examsAndQuizzes: "Exams",
        uploadMaterials: "Publish Content",
        publish: "Publish",
        student: "Student",
        academic: "Academic",
        admin: "Admin",
        status: "Status",
        actions: "Actions",
        // Home specific
        futureOf: "The Future of",
        medicalEducation: "Medical Education",
        heroSub: "A professional-grade simulation and learning environment for medical devices and pathological analysis. Built for universities, optimized for excellence.",
        getStarted: "Get Started Now",
        learnMore: "Learn More",
        medDevicesTitle: "Medical Devices",
        medDevicesDesc: "Master complex instrumentation through interactive virtual simulators and structured learning paths.",
        pathAnalysisTitle: "Pathological Analysis",
        pathAnalysisDesc: "Simulate real-world lab scenarios and analyze pathological data with instant AI-driven feedback.",
        certReadyTitle: "Certification Ready",
        certReadyDesc: "Secure, timed examinations that validate your skills and provide globally recognized achievement tracking.",
        pendingResults: "Exam Results",
        studentManagement: "Students",
        manageDepts: "Manage Departments",
        pending_review: "Under Review",
        approved: "Approved",
        contentUrl: "Content URL",
        aiHelp: "Ask anything about this device...",
        send: "Send",
        myCourses: "My Courses",
        exams: "Exams",
        certificates: "Certificates",
        profile: "Profile",
        settings: "Settings",
        searchPlaceholder: "Search for courses or devices...",
        welcomeBack: "Welcome back,",
        continueLearning: "Continue Learning",
        recommended: "Recommended for You",
        pathologicalAnalysis: "Pathological Analysis",
        medicalDevices: "Medical Devices",
        deviceManagement: "Device Management",
        addDevice: "Add Device",
        materialType: "Material Type",
        selectDevice: "Select Device",
        studentResults: "Student Results",
        activeStudents: "Active Students",
        totalMaterials: "Total Materials",
        publishedDevices: "Published Devices",
        model3d: "3D Model",
        image: "Image",
        file: "File",
        home: "Home",
        myProfile: "My Profile",
        coursesMaterials: "Courses & Materials",
        aiTutor: "AI Tutor",
        "3dTour": "3D Tour",
        myResults: "My Results",
        notifications: "Notifications",
        announcements: "Announcements",
        grading: "Grading"
    },
    ar: {
        appName: "Maharat Academy",
        login: "تسجيل الدخول",
        register: "إنشاء حساب",
        registerSub: "المنصة المهنية للتدريب المهني والطبي",
        fullName: "الاسم الكامل",
        role: "الدور المهني",
        department: "القسم",
        academicEmail: "البريد الأكاديمي",
        password: "كلمة المرور",
        loginSub: "ادخل إلى بيئة المختبر الخاصة بك",
        createAccount: "سجل الآن",
        alreadyHaveAccount: "مسجل بالفعل؟",
        noAccount: "ليس لديك حساب؟",
        entryLab: "دخول المختبر",
        overview: "نظرة عامة",
        departments: "الأقسام",
        userManagement: "إدارة المستخدمين",
        analytics: "التحليلات",
        systemOverview: "نظرة عامة على النظام",
        totalStudents: "إجمالي الطلاب",
        pendingApprovals: "طلبات معلقة",
        activeDepts: "الأقسام النشطة",
        examsTaken: "امتحانات مكتملة",
        recentRegistrations: "تسجيلات حديثة",
        approvals: "الموافقات",
        results: "النتائج",
        users: "المستخدمين",
        logout: "تسجيل الخروج",
        checkStatus: "تحديث الحالة",
        pendingApproval: "بانتظار الموافقة",
        pendingMsg: "حسابك قيد المراجعة من قبل المسؤول. يرجى الانتظار.",
        switchLang: "English",
        backToDash: "لوحة التحكم",
        learning: "التعلم",
        simulator: "المحاكي",
        assistant: "المساعد الذكي",
        certification: "الشهادة",
        loadSample: "تحميل عينة",
        calibrate: "معايرة",
        runAnalysis: "بدء التحليل",
        submitExam: "إرسال الامتحان",
        startExam: "بدء امتحان الشهادة",
        begin: "ابدأ الآن",
        examNotice: "هذا امتحان مؤقت. لا تقم بتحديث الصفحة.",
        myLearningPath: "مساري التعليمي",
        availableDevices: "الأجهزة المتاحة",
        overallProgress: "التقدم العام",
        devicesMastered: "أجهزة متقنة",
        examsPending: "بانتظار المراجعة",
        averageScore: "متوسط الدرجات",
        manageDevices: "الأجهزة",
        learningMaterials: "المواد",
        examsAndQuizzes: "الامتحانات",
        uploadMaterials: "نشر المحتوى",
        publish: "نشر",
        student: "طالب",
        academic: "أكاديمي",
        admin: "مدير النظام",
        status: "الحالة",
        actions: "الإجراءات",
        // Home specific
        futureOf: "مستقبل",
        medicalEducation: "التعليم الطبي",
        heroSub: "بيئة محاكاة وتعلم احترافية للأجهزة الطبية والتحليل المرضي. مصممة للجامعات، ومحسنة للتميز.",
        getStarted: "ابدأ الآن",
        learnMore: "اكتشف المزيد",
        medDevicesTitle: "الأجهزة الطبية",
        medDevicesDesc: "أتقن الأدوات المعقدة من خلال محاكيات افتراضية تفاعلية ومسارات تعليمية منظمة.",
        pathAnalysisTitle: "التحليل المرضي",
        pathAnalysisDesc: "حاكِ سيناريوهات المختبر الحقيقية وحلل البيانات المرضية مع تعليقات فورية ذكية.",
        certReadyTitle: "جاهز للاعتماد",
        certReadyDesc: "امتحانات مؤمنة وموقوتة تثبت مهاراتك وتوفر تتبعاً للإنجازات معترفاً به عالمياً.",
        pendingResults: "نتائج الامتحانات",
        studentManagement: "إدارة الطلاب",
        manageDepts: "إدارة الأقسام",
        pending_review: "قيد المراجعة",
        approved: "معتمد",
        contentUrl: "رابط المحتوى",
        aiHelp: "اسأل أي شيء عن هذا الجهاز...",
        send: "إرسال",
        myCourses: "دوراتي",
        exams: "الامتحانات",
        certificates: "الشهادات",
        profile: "الملف الشخصي",
        settings: "الإعدادات",
        searchPlaceholder: "ابحث عن الدورات أو الأجهزة...",
        welcomeBack: "مرحباً بك مجدداً،",
        continueLearning: "مواصلة التعلم",
        recommended: "مقترح لك",
        pathologicalAnalysis: "التحليل المرضي",
        medicalDevices: "الأجهزة الطبية",
        deviceManagement: "إدارة الأجهزة",
        addDevice: "إضافة جهاز",
        materialType: "نوع المادة",
        selectDevice: "اختر الجهاز",
        studentResults: "نتائج الطلاب",
        activeStudents: "الطلاب النشطون",
        totalMaterials: "إجمالي المواد",
        publishedDevices: "الأجهزة المنشورة",
        model3d: "مجسم 3D",
        image: "صورة",
        file: "ملف",
        home: "الرئيسية",
        myProfile: "الملف الشخصي",
        coursesMaterials: "الكورسات والمواد",
        aiTutor: "المساعد الذكي",
        "3dTour": "الجولة الافتراضية",
        myResults: "نتائجي",
        notifications: "الإشعارات",
        announcements: "الإعلانات",
        grading: "التقييم"
    }
};

class I18n {
    constructor() {
        this.lang = localStorage.getItem('sm_platform_lang') || 'en';
    }

    t(key) {
        return dictionaries[this.lang][key] || key;
    }

    extend(lang, newStrings) {
        if (dictionaries[lang]) {
            Object.assign(dictionaries[lang], newStrings);
        }
    }

    toggle() {
        this.lang = this.lang === 'en' ? 'ar' : 'en';
        localStorage.setItem('sm_platform_lang', this.lang);
        location.reload();
    }

    updateDOM() {
        document.documentElement.lang = this.lang;
        document.documentElement.dir = this.lang === 'ar' ? 'rtl' : 'ltr';
        
        document.querySelectorAll('[data-i18n]').forEach(el => {
            const key = el.getAttribute('data-i18n');
            const translation = this.t(key);
            
            if (el.tagName === 'INPUT' || el.tagName === 'TEXTAREA') {
                el.placeholder = translation;
            } else {
                el.textContent = translation;
            }
        });
    }
}

const i18n = new I18n();
export default i18n;
